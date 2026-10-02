#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="evidence/out/crc-${STAMP}"
mkdir -p "${OUT}"

echo "Evidence directory: ${OUT}"

set +e
bash scripts/runtime-smoke-openshift.sh 2>&1 | tee "${OUT}/runtime-smoke.txt"
smoke_status=${PIPESTATUS[0]}
set -e

oc get clusterversion version -o yaml > "${OUT}/clusterversion.yaml" 2>&1 || true
oc get clusteroperators -o yaml > "${OUT}/clusteroperators.yaml" 2>&1 || true
oc get nodes -o wide > "${OUT}/nodes.txt" 2>&1 || true
oc -n shared-observability get deploy,rs,svc,pods -o wide > "${OUT}/shared-observability.txt" 2>&1 || true
oc -n shared-observability describe deployment/otel-collector > "${OUT}/otel-deployment-describe.txt" 2>&1 || true
oc -n shared-observability get pods -l app=otel-collector -o yaml > "${OUT}/otel-pods.yaml" 2>&1 || true
oc -n shared-observability describe pods -l app=otel-collector > "${OUT}/otel-pods-describe.txt" 2>&1 || true
oc -n shared-observability get events --sort-by=.lastTimestamp > "${OUT}/events.txt" 2>&1 || true
oc -n shared-observability logs deploy/otel-collector --all-containers=true --tail=300 > "${OUT}/otel-collector.log" 2>&1 || true

if [[ "${smoke_status}" -ne 0 ]]; then
  echo "== Failure diagnostics"
  cat "${OUT}/shared-observability.txt" || true
  tail -n 80 "${OUT}/events.txt" || true
  echo "CRC_SHARED_OBSERVABILITY_EVIDENCE=FAIL"
  echo "Inspect ${OUT}/runtime-smoke.txt, ${OUT}/otel-pods-describe.txt and ${OUT}/events.txt."
  exit "${smoke_status}"
fi

echo "CRC_SHARED_OBSERVABILITY_EVIDENCE=PASS"
echo "Evidence is local and ignored by Git by default."
echo "Sanitize before promoting selected evidence into version control."
