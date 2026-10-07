#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-d093-i6c-olm}"
KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0}"
OPERATOR_SDK="${OPERATOR_SDK:-operator-sdk}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPERATOR_DIR="$ROOT_DIR/operators/platform-onboarding-operator"
TMP_DIR="$(mktemp -d)"

OPERATOR_V010="docker.io/library/mayabank-platform-operator:v0.1.0"
OPERATOR_V020="docker.io/library/mayabank-platform-operator:v0.2.0"
BUNDLE_V010="docker.io/library/mayabank-platform-operator-bundle:v0.1.0"
BUNDLE_V020="docker.io/library/mayabank-platform-operator-bundle:v0.2.0"

diagnostics() {
  echo "== I6C diagnostics =="
  kubectl get csv,subscription,catalogsource,operatorgroup -A || true
  kubectl get capabilityconsumptions.platform.mayabank.example -o yaml || true
  kubectl -n shared-platform-services get deploy,pod,sa -o wide || true
  kubectl get events -A --sort-by=.lastTimestamp | tail -n 200 || true
}

cleanup() {
  status=$?
  if [[ "$status" -ne 0 ]]; then
    diagnostics
  fi
  rm -rf "$TMP_DIR"
  kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT

wait_reason() {
  local name="$1"
  local expected="$2"
  local reason=""
  for _ in $(seq 1 120); do
    reason="$(kubectl get capabilityconsumption "$name" -o json 2>/dev/null | jq -r '.status.conditions[]? | select(.type=="Ready") | .reason' | tail -n1 || true)"
    if [[ "$reason" == "$expected" ]]; then
      echo "CapabilityConsumption/$name Ready reason=$reason"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for CapabilityConsumption/$name reason=$expected; observed=$reason" >&2
  return 1
}

wait_csv() {
  local name="$1"
  local phase=""
  for _ in $(seq 1 180); do
    phase="$(kubectl -n shared-platform-services get csv "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "$phase" == "Succeeded" ]]; then
      echo "CSV/$name phase=$phase"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for CSV/$name; observed=$phase" >&2
  return 1
}

echo "== I6C preflight =="
command -v docker
command -v kind
command -v kubectl
command -v jq
command -v "$OPERATOR_SDK"
"$OPERATOR_SDK" version

echo "== Create Kind cluster =="
kind create cluster --name "$CLUSTER_NAME" --image "$KIND_NODE_IMAGE" --wait 180s
kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl create namespace shared-platform-services

echo "== Build versioned Operator images =="
docker build -t "$OPERATOR_V010" -t "$OPERATOR_V020" "$OPERATOR_DIR"
kind load docker-image "$OPERATOR_V010" "$OPERATOR_V020" --name "$CLUSTER_NAME"

echo "== Prepare local bundle build contexts =="
cp -R "$OPERATOR_DIR/bundle-v0.1.0" "$TMP_DIR/bundle-v0.1.0"
cp -R "$OPERATOR_DIR/bundle" "$TMP_DIR/bundle"
cp "$OPERATOR_DIR/bundle-v0.1.0.Dockerfile" "$TMP_DIR/bundle-v0.1.0.Dockerfile"
cp "$OPERATOR_DIR/bundle.Dockerfile" "$TMP_DIR/bundle.Dockerfile"
sed -i "s#ghcr.io/zdmooc/mayabank-platform-operator:v0.1.0#$OPERATOR_V010#g" "$TMP_DIR/bundle-v0.1.0/manifests/mayabank-platform-operator.clusterserviceversion.yaml"
sed -i "s#ghcr.io/zdmooc/mayabank-platform-operator:v0.2.0#$OPERATOR_V020#g" "$TMP_DIR/bundle/manifests/mayabank-platform-operator.clusterserviceversion.yaml"

"$OPERATOR_SDK" bundle validate "$TMP_DIR/bundle-v0.1.0"
"$OPERATOR_SDK" bundle validate "$TMP_DIR/bundle"

docker build -f "$TMP_DIR/bundle-v0.1.0.Dockerfile" -t "$BUNDLE_V010" "$TMP_DIR"
docker build -f "$TMP_DIR/bundle.Dockerfile" -t "$BUNDLE_V020" "$TMP_DIR"
kind load docker-image "$BUNDLE_V010" "$BUNDLE_V020" --name "$CLUSTER_NAME"
echo "I6C_BUNDLE_VALIDATION=PASS"

echo "== Install OLM development runtime =="
"$OPERATOR_SDK" olm install
"$OPERATOR_SDK" olm status
echo "I6C_OLM_INSTALL=PASS"

echo "== Install bundle v0.1.0 through OLM =="
"$OPERATOR_SDK" run bundle "$BUNDLE_V010"   --namespace shared-platform-services   --install-mode AllNamespaces   --timeout 6m   --image-pull-policy IfNotPresent

wait_csv mayabank-platform-operator.v0.1.0
kubectl -n shared-platform-services rollout status deploy/mayabank-platform-operator --timeout=180s
[[ "$(kubectl -n shared-platform-services get deploy mayabank-platform-operator -o jsonpath='{.spec.replicas}')" == "2" ]]
echo "I6C_OLM_V010_INSTALL=PASS"

echo "== Reconcile a real CapabilityConsumption through OLM-managed Operator =="
cat <<'YAML' | kubectl apply -f -
apiVersion: platform.mayabank.example/v1alpha1
kind: CapabilityConsumption
metadata:
  name: i6c-olm-consumer
spec:
  consumer:
    name: i6c-olm-consumer
    owner: platform-engineering
    environment: kind-olm
  target:
    namespace: d093-i6c-consumer
  identity: {mode: REFERENCE_ONLY}
  observability: {mode: REFERENCE_ONLY}
  secrets: {mode: REFERENCE_ONLY}
  gitops: {mode: REFERENCE_ONLY}
  quality: {mode: REFERENCE_ONLY}
  eventing: {mode: REFERENCE_ONLY}
  database: {mode: REFERENCE_ONLY}
  objectStorage: {mode: REFERENCE_ONLY}
  resources:
    profile: small
  network:
    profile: restricted
  lifecycle:
    adoptionPolicy: Manage
    deletionPolicy: Retain
YAML

wait_reason i6c-olm-consumer Reconciled
kubectl -n d093-i6c-consumer get resourcequota platform-quota
echo "I6C_OLM_CONSUMER_RECONCILE=PASS"

echo "== Upgrade bundle v0.1.0 -> v0.2.0 =="
"$OPERATOR_SDK" run bundle-upgrade "$BUNDLE_V020"   --namespace shared-platform-services   --timeout 6m   --image-pull-policy IfNotPresent

wait_csv mayabank-platform-operator.v0.2.0
kubectl -n shared-platform-services rollout status deploy/mayabank-platform-operator --timeout=180s
wait_reason i6c-olm-consumer Reconciled
echo "I6C_OLM_UPGRADE=PASS"

echo "== Post-upgrade reconciliation continuity =="
kubectl -n d093-i6c-consumer delete resourcequota platform-quota
for _ in $(seq 1 120); do
  if kubectl -n d093-i6c-consumer get resourcequota platform-quota >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
kubectl -n d093-i6c-consumer get resourcequota platform-quota
wait_reason i6c-olm-consumer Reconciled
echo "I6C_POST_UPGRADE_RECONCILIATION=PASS"

echo "== OLM uninstall boundary =="
subscription="$(kubectl -n shared-platform-services get subscription -o json | jq -r '.items[] | select(.spec.name=="mayabank-platform-operator") | .metadata.name' | head -n1)"
[[ -n "$subscription" ]]
current_csv="$(kubectl -n shared-platform-services get subscription "$subscription" -o jsonpath='{.status.currentCSV}')"
[[ "$current_csv" == "mayabank-platform-operator.v0.2.0" ]]
kubectl -n shared-platform-services delete subscription "$subscription"
kubectl -n shared-platform-services delete csv "$current_csv"

for _ in $(seq 1 120); do
  if ! kubectl -n shared-platform-services get deploy mayabank-platform-operator >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
if kubectl -n shared-platform-services get deploy mayabank-platform-operator >/dev/null 2>&1; then
  echo "Operator deployment still present after CSV removal" >&2
  exit 1
fi

kubectl get crd capabilityconsumptions.platform.mayabank.example
kubectl get capabilityconsumption i6c-olm-consumer
kubectl get namespace d093-i6c-consumer
kubectl -n d093-i6c-consumer get resourcequota platform-quota
echo "I6C_UNINSTALL_RETAIN=PASS"

echo "I6C_KIND_OLM_LIFECYCLE_RESULT=PASS"
echo "claim=KIND_OLM_LIFECYCLE_PROVEN"
echo "openshift_operator_runtime_external_evidence=CONSUMER_1_CRC_RUNTIME_PROVEN"
echo "openshift_olm_lifecycle=NOT_PROVEN_BY_THIS_KIND_RUN"
