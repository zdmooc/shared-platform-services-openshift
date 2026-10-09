#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLM_NAMESPACE="${OLM_NAMESPACE:-d093-op2-olm}"
CONSUMER_NAME="${CONSUMER_NAME:-d093-op2-olm-consumer}"
CONSUMER_NAMESPACE="${CONSUMER_NAMESPACE:-d093-op2-consumer}"
DIRECT_OPERATOR_NAMESPACE="${DIRECT_OPERATOR_NAMESPACE:-shared-platform-services}"
DIRECT_OPERATOR_DEPLOYMENT="${DIRECT_OPERATOR_DEPLOYMENT:-mayabank-platform-operator}"

BUNDLE_V010="${BUNDLE_V010:-ghcr.io/zdmooc/mayabank-platform-operator-bundle:v0.1.0}"
BUNDLE_V020="${BUNDLE_V020:-ghcr.io/zdmooc/mayabank-platform-operator-bundle:v0.2.0}"
OPERATOR_V010="${OPERATOR_V010:-ghcr.io/zdmooc/mayabank-platform-operator:v0.1.0}"
OPERATOR_V020="${OPERATOR_V020:-ghcr.io/zdmooc/mayabank-platform-operator:v0.2.0}"
KEEP_TEST_RESOURCES="${KEEP_TEST_RESOURCES:-false}"

DIRECT_REPLICAS=""
DIRECT_PRESENT=false
OLM_CREATED=false
CONSUMER_CREATED=false
OLM_COMPLETED=false

log() {
  printf '%s\n' "$*"
}

diagnostics() {
  log "== OP2 diagnostics =="
  oc get clusterversion || true
  oc api-resources | grep -E 'ClusterServiceVersion|Subscription|OperatorGroup|CatalogSource|ClusterCatalog|ClusterExtension' || true
  oc -n "$OLM_NAMESPACE" get csv,subscription,operatorgroup,deploy,pod -o wide 2>/dev/null || true
  oc get capabilityconsumptions.platform.mayabank.example -o wide 2>/dev/null || true
  oc -n "$CONSUMER_NAMESPACE" get resourcequota,limitrange,role,rolebinding,networkpolicy 2>/dev/null || true
  oc get events -A --sort-by=.lastTimestamp | tail -n 120 || true
}

restore_direct_operator() {
  if [[ "$DIRECT_PRESENT" == "true" && -n "$DIRECT_REPLICAS" ]]; then
    log "== Restore direct Operator replicas=$DIRECT_REPLICAS =="
    if ! oc -n "$DIRECT_OPERATOR_NAMESPACE" scale deploy/"$DIRECT_OPERATOR_DEPLOYMENT" --replicas="$DIRECT_REPLICAS" >/dev/null; then
      log "ERROR: failed to restore direct Operator replica count." >&2
      return 1
    fi
    if [[ "$DIRECT_REPLICAS" != "0" ]]; then
      if ! oc -n "$DIRECT_OPERATOR_NAMESPACE" rollout status deploy/"$DIRECT_OPERATOR_DEPLOYMENT" --timeout=180s; then
        log "ERROR: direct Operator did not become ready after restore." >&2
        return 1
      fi
    fi
    log "OP2_DIRECT_OPERATOR_RESTORE=PASS"
  fi
}

cleanup_test_resources() {
  if [[ "$KEEP_TEST_RESOURCES" == "true" ]]; then
    log "KEEP_TEST_RESOURCES=true; OP2 test resources retained."
    return
  fi

  # Only delete resources created by this invocation. In particular, a failed
  # preflight must never delete namespaces or a CapabilityConsumption that existed
  # before the run.
  if [[ "$CONSUMER_CREATED" == "true" ]]; then
    oc delete capabilityconsumption "$CONSUMER_NAME" --wait=false >/dev/null 2>&1 || true
    oc delete namespace "$CONSUMER_NAMESPACE" --wait=false >/dev/null 2>&1 || true
  fi
  if [[ "$OLM_CREATED" == "true" ]]; then
    oc delete namespace "$OLM_NAMESPACE" --wait=false >/dev/null 2>&1 || true
  fi
}

cleanup() {
  local status=$?
  trap - EXIT
  if [[ "$status" -ne 0 ]]; then
    if [[ "$DIRECT_PRESENT" == "true" || "$OLM_CREATED" == "true" || "$CONSUMER_CREATED" == "true" ]]; then
      diagnostics
    else
      log "OP2_PREFLIGHT_ABORTED_WITHOUT_MUTATION=PASS"
      log "No operator park or test-resource creation was attempted."
    fi
  fi
  cleanup_test_resources
  if ! restore_direct_operator; then
    log "OP2_DIRECT_OPERATOR_RESTORE=FAILED; investigate CRC before further action." >&2
    status=80
  fi
  if [[ "$status" -eq 0 && "$OLM_COMPLETED" == "true" ]]; then
    log "OP2_OPENSHIFT_OLM_LIFECYCLE_RESULT=PASS"
    log "claim=OPENSHIFT_OLM_LIFECYCLE_PROVEN_CRC"
    log "truth_boundary=CRC_SINGLE_NODE_NOT_PRODUCTION_HA"
  fi
  exit "$status"
}
trap cleanup EXIT

wait_ready_reason() {
  local name="$1"
  local expected="$2"
  local reason=""
  for _ in $(seq 1 150); do
    reason="$(oc get capabilityconsumption "$name" -o json 2>/dev/null | jq -r '.status.conditions[]? | select(.type=="Ready") | .reason' | tail -n1 || true)"
    if [[ "$reason" == "$expected" ]]; then
      log "CapabilityConsumption/$name Ready reason=$reason"
      return 0
    fi
    sleep 2
  done
  log "Timed out waiting for CapabilityConsumption/$name reason=$expected; observed=$reason" >&2
  return 1
}

wait_csv() {
  local version="$1"
  local name="mayabank-platform-operator.v$version"
  local phase=""
  for _ in $(seq 1 240); do
    phase="$(oc -n "$OLM_NAMESPACE" get csv "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "$phase" == "Succeeded" ]]; then
      log "CSV/$name phase=$phase"
      return 0
    fi
    sleep 2
  done
  log "Timed out waiting for CSV/$name; observed=$phase" >&2
  return 1
}

image_preflight() {
  local image="$1"
  log "Checking image: $image"
  if oc image info "$image" >/dev/null 2>&1; then
    return 0
  fi
  log "Image unavailable or inaccessible with current registry credentials: $image" >&2
  log "Inspect registry existence and authentication separately; do not assume an image was published." >&2
  log "GHCR publication workflow must be present on the default branch before GitHub workflow_dispatch can run." >&2
  return 1
}

log "== OP2 preflight =="
command -v oc
command -v jq
if [[ "${OP2_PREFLIGHT_ONLY:-false}" != "true" ]]; then
  command -v operator-sdk
fi

oc whoami
api_server="$(oc whoami --show-server)"
if [[ "$api_server" != "https://api.crc.testing:6443" ]]; then
  printf 'ERROR: expected OpenShift Local CRC API https://api.crc.testing:6443; observed %s\n' "$api_server" >&2
  exit 18
fi
oc get clusterversion
server_version="$(oc version -o json | jq -r '.openshiftVersion // .serverVersion.gitVersion // "unknown"')"
log "OpenShift server version: $server_version"

for resource in   clusterserviceversions.operators.coreos.com   subscriptions.operators.coreos.com   operatorgroups.operators.coreos.com   catalogsources.operators.coreos.com
do
  oc get --raw "/apis/${resource#*.}" >/dev/null 2>&1 || true
done

# Capture the resource discovery response exactly once. Under set -o pipefail,
# piping 'oc api-resources' into 'grep -q' can produce SIGPIPE (141) after
# grep matches early, which was observed as a silent CRC WSL preflight abort.
# A here-string keeps the producer out of grep's pipeline.
if ! olm_api_resources="$(oc api-resources)"; then
  log "OP2_OLM_API_DISCOVERY_FAILED=oc api-resources" >&2
  exit 24
fi
for required_kind in ClusterServiceVersion Subscription OperatorGroup CatalogSource; do
  if ! grep -Fq "$required_kind" <<<"$olm_api_resources"; then
    log "OP2_OLM_API_MISSING=$required_kind" >&2
    exit 24
  fi
done
log "OP2_OLM_CLASSIC_APIS=PASS"

for image in "$OPERATOR_V010" "$OPERATOR_V020" "$BUNDLE_V010" "$BUNDLE_V020"; do
  image_preflight "$image"
done
log "OP2_GHCR_IMAGES_PULLABLE=PASS"

if oc get namespace "$OLM_NAMESPACE" >/dev/null 2>&1; then
  log "Namespace $OLM_NAMESPACE already exists; refusing to reuse it." >&2
  exit 20
fi
if oc get namespace "$CONSUMER_NAMESPACE" >/dev/null 2>&1; then
  log "Namespace $CONSUMER_NAMESPACE already exists; refusing to reuse it." >&2
  exit 21
fi
if oc get capabilityconsumption "$CONSUMER_NAME" >/dev/null 2>&1; then
  log "CapabilityConsumption/$CONSUMER_NAME already exists; refusing to overwrite it." >&2
  exit 22
fi

# Safe, explicitly read-only readiness mode for preparing the CRC window.
# Stops before parking the direct Operator or creating any test resources.
if [[ "${OP2_PREFLIGHT_ONLY:-false}" == "true" ]]; then
  log "OP2_PREFLIGHT_READONLY=PASS"
  log "No deployment scaled, no resource created or deleted."
  exit 0
fi

# Full OLM replay changes controller availability and test resources: opt-in only.
if [[ "${CONFIRM_OP2_CRC_MUTATIONS:-}" != "YES_I_AUTHORIZE_OP2_OPERATOR_PARK_AND_TEST_CLEANUP" ]]; then
  log "OP2_MUTATION_AUTHORIZATION_REQUIRED: inspect the runbook and explicitly opt in." >&2
  exit 23
fi

if oc -n "$DIRECT_OPERATOR_NAMESPACE" get deploy "$DIRECT_OPERATOR_DEPLOYMENT" >/dev/null 2>&1; then
  DIRECT_PRESENT=true
  DIRECT_REPLICAS="$(oc -n "$DIRECT_OPERATOR_NAMESPACE" get deploy "$DIRECT_OPERATOR_DEPLOYMENT" -o jsonpath='{.spec.replicas}')"
  log "Direct Operator detected with replicas=$DIRECT_REPLICAS"
  oc -n "$DIRECT_OPERATOR_NAMESPACE" scale deploy/"$DIRECT_OPERATOR_DEPLOYMENT" --replicas=0
  oc -n "$DIRECT_OPERATOR_NAMESPACE" rollout status deploy/"$DIRECT_OPERATOR_DEPLOYMENT" --timeout=120s || true
  log "OP2_DIRECT_OPERATOR_PARK=PASS"
else
  log "Direct Operator deployment not present; no park required."
fi

oc create namespace "$OLM_NAMESPACE"
OLM_CREATED=true

log "== Install v0.1.0 through OLM on OpenShift =="
operator-sdk run bundle "$BUNDLE_V010"   --namespace "$OLM_NAMESPACE"   --install-mode AllNamespaces   --timeout 8m   --image-pull-policy Always

wait_csv "0.1.0"
oc -n "$OLM_NAMESPACE" rollout status deploy/mayabank-platform-operator --timeout=240s
log "OP2_OPENSHIFT_OLM_V010_INSTALL=PASS"

log "== Reconcile dedicated OP2 consumer =="
cat <<YAML | oc apply -f -
apiVersion: platform.mayabank.example/v1alpha1
kind: CapabilityConsumption
metadata:
  name: $CONSUMER_NAME
spec:
  consumer:
    name: $CONSUMER_NAME
    owner: platform-engineering
    environment: crc-olm
  target:
    namespace: $CONSUMER_NAMESPACE
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
CONSUMER_CREATED=true

wait_ready_reason "$CONSUMER_NAME" Reconciled
oc -n "$CONSUMER_NAMESPACE" get resourcequota platform-quota
log "OP2_OPENSHIFT_OLM_CONSUMER_RECONCILE=PASS"

log "== Upgrade v0.1.0 -> v0.2.0 through OLM =="
operator-sdk run bundle-upgrade "$BUNDLE_V020"   --namespace "$OLM_NAMESPACE"   --timeout 8m   --image-pull-policy Always

wait_csv "0.2.0"
oc -n "$OLM_NAMESPACE" rollout status deploy/mayabank-platform-operator --timeout=240s
wait_ready_reason "$CONSUMER_NAME" Reconciled
log "OP2_OPENSHIFT_OLM_UPGRADE=PASS"

log "== Post-upgrade reconciliation continuity =="
oc -n "$CONSUMER_NAMESPACE" delete resourcequota platform-quota
for _ in $(seq 1 120); do
  if oc -n "$CONSUMER_NAMESPACE" get resourcequota platform-quota >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
oc -n "$CONSUMER_NAMESPACE" get resourcequota platform-quota
wait_ready_reason "$CONSUMER_NAME" Reconciled
log "OP2_OPENSHIFT_POST_UPGRADE_RECONCILIATION=PASS"

log "== OLM uninstall / Retain boundary =="
subscription="$(oc -n "$OLM_NAMESPACE" get subscription -o json | jq -r '.items[] | select(.spec.name=="mayabank-platform-operator") | .metadata.name' | head -n1)"
if [[ -z "$subscription" ]]; then
  log "Unable to find mayabank-platform-operator Subscription" >&2
  exit 30
fi
current_csv="$(oc -n "$OLM_NAMESPACE" get subscription "$subscription" -o jsonpath='{.status.currentCSV}')"
oc -n "$OLM_NAMESPACE" delete subscription "$subscription"
oc -n "$OLM_NAMESPACE" delete csv "$current_csv"

for _ in $(seq 1 120); do
  if ! oc -n "$OLM_NAMESPACE" get deploy mayabank-platform-operator >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
if oc -n "$OLM_NAMESPACE" get deploy mayabank-platform-operator >/dev/null 2>&1; then
  log "Operator deployment still present after CSV deletion" >&2
  exit 31
fi

oc get crd capabilityconsumptions.platform.mayabank.example
oc get capabilityconsumption "$CONSUMER_NAME"
oc get namespace "$CONSUMER_NAMESPACE"
oc -n "$CONSUMER_NAMESPACE" get resourcequota platform-quota

log "OP2_OPENSHIFT_OLM_UNINSTALL_RETAIN=PASS"
# Final PASS is emitted by cleanup only after the original direct Operator is restored.
OLM_COMPLETED=true
