#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARGO_NAMESPACE="${ARGO_NAMESPACE:-openshift-gitops}"
ARGO_APP="${ARGO_APP:-instant-payments-tech-lead-shared-platform}"
PAYMENT_NAMESPACE="${PAYMENT_NAMESPACE:-instant-payments-local}"
CAPABILITY_CONSUMPTION="${CAPABILITY_CONSUMPTION:-instant-payments-crc}"
OPERATOR_NAMESPACE="${OPERATOR_NAMESPACE:-shared-platform-services}"

for cmd in grep bash; do
  command -v "$cmd" >/dev/null || { echo "ERROR: $cmd is required" >&2; exit 1; }
done

echo "== OP4 repository preflight =="

for file in   "$ROOT_DIR/operators/platform-onboarding-operator/api/v1alpha1/capabilityconsumption_types.go"   "$ROOT_DIR/operators/platform-onboarding-operator/internal/controller/capabilityconsumption_controller.go"   "$ROOT_DIR/docs/iterations/D093-I6A-OPERATOR-HARDENING.md"   "$ROOT_DIR/docs/iterations/D093-I6C-OLM-OPENSHIFT-PACKAGING.md"
do
  test -f "$file"
done

grep -q 'func (r \*CapabilityConsumptionReconciler) Reconcile'   "$ROOT_DIR/operators/platform-onboarding-operator/internal/controller/capabilityconsumption_controller.go"
grep -q 'FieldManager.*mayabank-platform-operator'   "$ROOT_DIR/operators/platform-onboarding-operator/internal/controller/capabilityconsumption_controller.go"
grep -q 'replaces: mayabank-platform-operator.v0.1.0'   "$ROOT_DIR/operators/platform-onboarding-operator/bundle/manifests/mayabank-platform-operator.clusterserviceversion.yaml"

echo "OP4_REPOSITORY_SURFACE=PASS"

if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
  echo
  echo "== OP4 live OpenShift read-only preflight =="
  command -v jq >/dev/null || { echo "ERROR: jq is required for live preflight" >&2; exit 1; }

  oc get clusterversion
  oc get capabilityconsumption "$CAPABILITY_CONSUMPTION"
  oc -n "$PAYMENT_NAMESPACE" get deploy wero-ui resourcequota platform-quota
  oc -n "$ARGO_NAMESPACE" get application "$ARGO_APP"
  oc -n "$OPERATOR_NAMESPACE" get deploy,pod,lease 2>/dev/null || true

  sync="$(oc -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o jsonpath='{.status.sync.status}')"
  health="$(oc -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o jsonpath='{.status.health.status}')"
  ready_reason="$(oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" -o json | jq -r '.status.conditions[]? | select(.type=="Ready") | .reason' | tail -n1)"

  echo "Argo sync=$sync health=$health"
  echo "CapabilityConsumption Ready reason=$ready_reason"

  [[ "$sync" == "Synced" ]]
  [[ "$health" == "Healthy" ]]
  [[ "$ready_reason" == "Reconciled" ]]

  if oc api-resources | grep -q 'ClusterServiceVersion'; then
    echo "OP4_OLM_CLASSIC_API=AVAILABLE"
  else
    echo "OP4_OLM_CLASSIC_API=NOT_AVAILABLE"
  fi

  if oc api-resources | grep -q 'ClusterExtension'; then
    echo "OP4_OLM_V1_API=AVAILABLE"
  else
    echo "OP4_OLM_V1_API=NOT_AVAILABLE"
  fi

  echo "OP4_OPENSHIFT_READONLY_PREFLIGHT=PASS"
else
  echo
  echo "No authenticated OpenShift session detected; repository-only preflight completed."
  echo "OP4_OPENSHIFT_READONLY_PREFLIGHT=NOT_OBSERVED"
fi

echo
echo "== Demo sequence =="
echo "1. bash scripts/d093-op1-operator-interview-surface.sh"
echo "2. bash scripts/d093-op3-operator-argocd-day2.sh     # live mutation demo, after review"
echo "3. bash scripts/d093-op2-olm-crc.sh                  # full OLM replay, after image preflight"
echo
echo "OP4_DEMO_PREFLIGHT=PASS"
