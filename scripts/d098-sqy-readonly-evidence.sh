#!/usr/bin/env bash
set -euo pipefail

# D-098 read-only evidence inventory.
# No apply/patch/delete/scale operations.

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="${1:-evidence/out/d098-sqy-$STAMP}"
mkdir -p "$OUT"

run() {
  local name="$1"; shift
  echo "===== $name ====="
  "$@" 2>&1 | tee "$OUT/$name.txt"
}

run whoami oc whoami
run server oc whoami --show-server
run version oc version
run clusterversion oc get clusterversion -o wide
run clusteroperators oc get clusteroperators
run nodes oc get nodes -o wide
run projects oc get projects
run routes oc get routes -A
run scc oc get scc
run subscriptions oc get subscriptions.operators.coreos.com -A
run csv oc get csv -A
run installplans oc get installplans.operators.coreos.com -A
run storageclasses oc get storageclass
run pvc oc get pvc -A
run networkpolicies oc get networkpolicy -A

oc get applications.argoproj.io -A > "$OUT/argocd-applications.txt" 2>&1 || true
oc get capabilityconsumptions.platform.mayabank.example -A -o wide > "$OUT/capabilityconsumptions.txt" 2>&1 || true

echo "D098_SQY_READONLY_EVIDENCE=PASS" | tee "$OUT/result.txt"
echo "Evidence directory: $OUT"
