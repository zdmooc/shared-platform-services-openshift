#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPERATOR_DIR="$ROOT_DIR/operators/platform-onboarding-operator"

echo "== DAAROPS OP1 — Operator interview surface =="
echo "Repository: $ROOT_DIR"

echo
echo "== API / CRD markers =="
grep -nE 'kubebuilder:resource|kubebuilder:subresource|kubebuilder:printcolumn|AdoptionObserve|AdoptionManage|DeletionRetain'   "$OPERATOR_DIR/api/v1alpha1/capabilityconsumption_types.go"

echo
echo "== Reconcile / ownership markers =="
grep -nE 'func \(r \*CapabilityConsumptionReconciler\) Reconcile|detectConflicts|AdoptionObserve|AdoptionManage|retryableFailure|FieldManager|ApplyOptions|OwnershipConflict|ConditionDegraded|ConditionProgressing'   "$OPERATOR_DIR/internal/controller/capabilityconsumption_controller.go"

echo
echo "== Watches / continuous reconciliation =="
grep -nE 'Watches\(&corev1.Namespace|Watches\(&corev1.ServiceAccount|Watches\(&corev1.ResourceQuota|Watches\(&corev1.LimitRange|Watches\(&rbacv1.Role|Watches\(&rbacv1.RoleBinding|Watches\(&networkingv1.NetworkPolicy'   "$OPERATOR_DIR/internal/controller/capabilityconsumption_controller.go"

echo
echo "== Leader election markers =="
grep -nE 'LeaderElection|leader-elect|LeaderElectionID'   "$OPERATOR_DIR/cmd/main.go"   "$OPERATOR_DIR/config/manager/manager.yaml"   "$OPERATOR_DIR/Makefile" || true

echo
echo "== Prometheus metrics markers =="
grep -nE 'mayabank_platform_operator|retryable|reconcile'   "$OPERATOR_DIR/internal/controller/metrics.go"

echo
echo "== OLM packaging markers =="
grep -nE 'name: mayabank-platform-operator.v|replaces:|version:'   "$OPERATOR_DIR/bundle/manifests/mayabank-platform-operator.clusterserviceversion.yaml"   "$OPERATOR_DIR/bundle-v0.1.0/manifests/mayabank-platform-operator.clusterserviceversion.yaml"

echo
echo "OP1_OPERATOR_INTERVIEW_SURFACE_READY=PASS"

if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
  echo
  echo "== Optional live OpenShift read-only evidence =="
  oc version || true
  oc get crd capabilityconsumptions.platform.mayabank.example || true
  oc get capabilityconsumptions.platform.mayabank.example -o wide || true
  oc -n shared-platform-services get deploy,pod,lease 2>/dev/null || true
  echo "OP1_OPENSHIFT_READONLY_SURFACE=OBSERVED"
else
  echo
  echo "OpenShift session not detected; static/interview surface only."
  echo "OP1_OPENSHIFT_READONLY_SURFACE=NOT_OBSERVED"
fi
