#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-shared-platform-ci}"
KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:v1.31.0}"

command -v kind >/dev/null
command -v kubectl >/dev/null

cleanup() {
  status=$?
  if [[ "${status}" -ne 0 ]]; then
    echo "== Failure diagnostics before cluster deletion"
    kubectl get nodes -o wide || true
    kubectl get pods -A -o wide || true
    kubectl get events -A --sort-by=.lastTimestamp | tail -n 100 || true
    kubectl -n shared-observability logs deploy/otel-collector --tail=200 || true
  fi
  kind delete cluster --name "${CLUSTER_NAME}" >/dev/null 2>&1 || true
  exit "${status}"
}
trap cleanup EXIT

echo "== Create ephemeral Kind cluster"
kind create cluster --name "${CLUSTER_NAME}" --image "${KIND_NODE_IMAGE}" --wait 180s
kubectl wait --for=condition=Ready node --all --timeout=120s

echo "== Apply shared platform runtime slice"
kubectl apply -k platform/runtime-ci
kubectl -n shared-observability rollout status deploy/otel-collector --timeout=180s

echo "== Validate platform namespaces and service"
kubectl get namespaces shared-platform-services shared-observability shared-identity shared-quality
kubectl -n shared-observability get deploy,svc
kubectl -n shared-observability get endpoints otel-collector

echo "== Prove consumer -> OTLP -> Collector -> Prometheus path"
bash scripts/smoke-otel-consumer.sh

echo "== Collector log sanity"
kubectl -n shared-observability logs deploy/otel-collector --tail=100

echo "S5_KIND_RUNTIME_SMOKE=PASS"
echo "S5_OTLP_CONSUMER_TO_PROMETHEUS=PASS"
echo "claim=CI_RUNTIME_PROVEN_KIND"
echo "crc_claim=NOT_PROVEN"
