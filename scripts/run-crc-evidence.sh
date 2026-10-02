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
oc -n shared-observability get deploy,svc,pods -o wide > "${OUT}/shared-observability.txt" 2>&1 || true
oc -n shared-observability logs deploy/otel-collector --tail=300 > "${OUT}/otel-collector.log" 2>&1 || true

if [[ "${smoke_status}" -ne 0 ]]; then
  echo "CRC_SHARED_OBSERVABILITY_EVIDENCE=FAIL"
  echo "Inspect ${OUT}/runtime-smoke.txt and captured diagnostics."
  exit "${smoke_status}"
fi

echo "CRC_SHARED_OBSERVABILITY_EVIDENCE=PASS"
echo "Evidence is local and ignored by Git by default."
echo "Sanitize before promoting selected evidence into version control."
