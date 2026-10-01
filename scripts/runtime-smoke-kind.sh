#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-shared-platform-ci}"
KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:v1.31.0}"

command -v kind >/dev/null
command -v kubectl >/dev/null

cleanup() {
  kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

kind create cluster --name "$CLUSTER_NAME" --image "$KIND_NODE_IMAGE" --wait 120s
kubectl apply -k platform/runtime-ci
kubectl -n shared-observability rollout status deploy/otel-collector --timeout=180s

kubectl run telemetry-smoke   --namespace shared-observability   --image=curlimages/curl:8.10.1   --restart=Never   --rm -i   --command -- sh -ec '
    curl -fsS http://otel-collector.shared-observability.svc:8889/metrics >/tmp/metrics
    grep -Eq "otelcol_|target_info|promhttp" /tmp/metrics
  '

kubectl get namespaces shared-platform-services shared-observability shared-identity shared-quality
kubectl -n shared-observability get deploy,svc

echo "S5_KIND_RUNTIME_SMOKE=PASS"
echo "claim=CI_RUNTIME_PROVEN_KIND_SINGLE_NODE"
echo "crc_claim=NOT_PROVEN"
