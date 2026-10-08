#!/usr/bin/env bash
set -euo pipefail

ARGO_NAMESPACE="${ARGO_NAMESPACE:-openshift-gitops}"
ARGO_APP="${ARGO_APP:-instant-payments-tech-lead-shared-platform}"
PAYMENT_NAMESPACE="${PAYMENT_NAMESPACE:-instant-payments-local}"
CAPABILITY_CONSUMPTION="${CAPABILITY_CONSUMPTION:-instant-payments-crc}"
PRODUCT_DEPLOYMENT="${PRODUCT_DEPLOYMENT:-wero-ui}"
PLATFORM_QUOTA="${PLATFORM_QUOTA:-platform-quota}"
TIMEOUT="${TIMEOUT_SECONDS:-240}"

ORIGINAL_REPLICAS=""
ORIGINAL_STORAGE=""
PRODUCT_DRIFT_INJECTED=false
PLATFORM_DRIFT_INJECTED=false

log() {
  printf '%s\n' "$*"
}

wait_jsonpath() {
  local resource="$1" jsonpath="$2" expected="$3" namespace="$4"
  local value=""
  local deadline=$((SECONDS + TIMEOUT))
  while (( SECONDS < deadline )); do
    value="$(oc -n "$namespace" get "$resource" -o "jsonpath=$jsonpath" 2>/dev/null || true)"
    if [[ "$value" == "$expected" ]]; then
      return 0
    fi
    sleep 2
  done
  log "Timed out waiting for $resource $jsonpath=$expected (last=$value)" >&2
  return 1
}

wait_capability_reason() {
  local expected="$1"
  local reason=""
  local deadline=$((SECONDS + TIMEOUT))
  while (( SECONDS < deadline )); do
    reason="$(oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" -o json 2>/dev/null | jq -r '.status.conditions[]? | select(.type=="Ready") | .reason' | tail -n1 || true)"
    if [[ "$reason" == "$expected" ]]; then
      return 0
    fi
    sleep 2
  done
  log "Timed out waiting for CapabilityConsumption/$CAPABILITY_CONSUMPTION Ready reason=$expected (last=$reason)" >&2
  return 1
}

restore_on_failure() {
  local status=$?
  trap - EXIT
  if [[ "$status" -ne 0 ]]; then
    if [[ "$PRODUCT_DRIFT_INJECTED" != "true" && "$PLATFORM_DRIFT_INJECTED" != "true" ]]; then
      log "OP3_EXIT_WITHOUT_MUTATION=PASS (no drift injected, no rollback required)"
    else
      log "== OP3 bounded recovery diagnostics =="
      oc -n "$PAYMENT_NAMESPACE" get deployment/"$PRODUCT_DEPLOYMENT" resourcequota/"$PLATFORM_QUOTA" -o wide 2>/dev/null || true
    fi

    if [[ "$PRODUCT_DRIFT_INJECTED" == "true" && -n "$ORIGINAL_REPLICAS" ]]; then
      oc -n "$PAYMENT_NAMESPACE" patch deploy "$PRODUCT_DEPLOYMENT" --type merge         -p "{\"spec\":{\"replicas\":$ORIGINAL_REPLICAS}}" >/dev/null 2>&1 || true
    fi

    if [[ "$PLATFORM_DRIFT_INJECTED" == "true" && -n "$ORIGINAL_STORAGE" ]]; then
      oc -n "$PAYMENT_NAMESPACE" patch resourcequota "$PLATFORM_QUOTA" --type merge         -p "{\"spec\":{\"hard\":{\"requests.storage\":\"$ORIGINAL_STORAGE\"}}}" >/dev/null 2>&1 || true
    fi
  fi
  exit "$status"
}
trap restore_on_failure EXIT

for cmd in oc jq; do
  command -v "$cmd" >/dev/null || { log "ERROR: $cmd is required" >&2; exit 1; }
done

log "== OP3 preflight =="
oc whoami
api_server="$(oc whoami --show-server)"
if [[ "$api_server" != "https://api.crc.testing:6443" ]]; then
  printf 'ERROR: expected OpenShift Local CRC API https://api.crc.testing:6443; observed %s\n' "$api_server" >&2
  exit 18
fi
oc get clusterversion
oc api-resources | grep -qE '^applications[[:space:]].*argoproj.io'

oc -n "$ARGO_NAMESPACE" get application "$ARGO_APP" >/dev/null
oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" >/dev/null
oc -n "$PAYMENT_NAMESPACE" get deploy "$PRODUCT_DEPLOYMENT" >/dev/null
oc -n "$PAYMENT_NAMESPACE" get resourcequota "$PLATFORM_QUOTA" >/dev/null

wait_jsonpath "application/$ARGO_APP" '{.status.sync.status}' "Synced" "$ARGO_NAMESPACE"
wait_jsonpath "application/$ARGO_APP" '{.status.health.status}' "Healthy" "$ARGO_NAMESPACE"

if [[ "${OP3_PREFLIGHT_ONLY:-false}" == "true" ]]; then
  capability_state="$(oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" -o json)"
  ready_reason="$(printf '%s' "$capability_state" | jq -r '[.status.conditions[]? | select(.type=="Ready") | .reason] | last // "NoReadyCondition"')"
  if [[ "$ready_reason" != "Reconciled" ]]; then
    log "OP3_PREFLIGHT_BLOCKED=OPERATOR_NOT_RECONCILED"
    printf '%s' "$capability_state" | jq -r '.status.conditions[]? | select(.type=="Ready") | "Ready=\(.status) reason=\(.reason) lastTransitionTime=\(.lastTransitionTime) message=\(.message)"'
    log "== Operator deployment (read-only) =="
    oc -n shared-platform-services get deploy/mayabank-platform-operator -o wide 2>/dev/null || true
    log "== Tekton proxy webhook endpoints (read-only) =="
    oc -n openshift-pipelines get endpoints/tekton-operator-proxy-webhook -o wide 2>/dev/null || true
    log "An old Ready condition alone does not prove the webhook is still unavailable now."
    exit 32
  fi
else
  wait_capability_reason Reconciled
fi

adoption="$(oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" -o jsonpath='{.spec.lifecycle.adoptionPolicy}')"
[[ "$adoption" == "Manage" ]] || {
  log "CapabilityConsumption/$CAPABILITY_CONSUMPTION is not in Manage mode: $adoption" >&2
  exit 10
}

log "OP3_ARGO_INITIAL_SYNC=PASS"
log "OP3_ARGO_INITIAL_HEALTH=PASS"
log "OP3_OPERATOR_INITIAL_RECONCILED=PASS"

log
log "== Ownership boundary =="
managed_kinds="$(oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" -o json | jq -r '.status.managedResources[]?.kind' | sort -u)"
printf '%s\n' "$managed_kinds"
grep -qx 'ResourceQuota' <<<"$managed_kinds"
if grep -qx 'Deployment' <<<"$managed_kinds"; then
  log "Operator unexpectedly reports Deployment ownership." >&2
  exit 11
fi

argo_tracks_product=false
if oc -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o json   | jq -e --arg ns "$PAYMENT_NAMESPACE" --arg name "$PRODUCT_DEPLOYMENT"       '.status.resources[]? | select(.kind=="Deployment" and .namespace==$ns and .name==$name)' >/dev/null
then
  argo_tracks_product=true
fi

if [[ "$argo_tracks_product" != "true" ]]; then
  log "Argo Application does not currently report Deployment/$PRODUCT_DEPLOYMENT in status.resources." >&2
  exit 12
fi

log "OP3_OPERATOR_PLATFORM_OWNERSHIP=PASS"
log "OP3_ARGO_PRODUCT_OWNERSHIP=PASS"
log "OP3_OWNERSHIP_BOUNDARY=PASS"

if [[ "${OP3_PREFLIGHT_ONLY:-false}" == "true" ]]; then
  log "OP3_PREFLIGHT_READONLY=PASS"
  log "No product Deployment or platform ResourceQuota changed."
  exit 0
fi

# This test changes a live product Deployment and ResourceQuota. Never mutate
# the CRC without an explicitly approved bounded runtime window.
if [[ "${CONFIRM_OP3_CRC_DRIFT:-}" != "YES_I_AUTHORIZE_OP3_CONTROLLED_DRIFT" ]]; then
  log "OP3_MUTATION_AUTHORIZATION_REQUIRED: ownership preflight only." >&2
  exit 40
fi

log
log "== Product drift: Argo CD self-heal =="
ORIGINAL_REPLICAS="$(oc -n "$PAYMENT_NAMESPACE" get deploy "$PRODUCT_DEPLOYMENT" -o jsonpath='{.spec.replicas}')"
DRIFT_REPLICAS=$((ORIGINAL_REPLICAS + 1))
oc -n "$PAYMENT_NAMESPACE" patch deploy "$PRODUCT_DEPLOYMENT" --type merge   -p "{\"spec\":{\"replicas\":$DRIFT_REPLICAS}}" >/dev/null
PRODUCT_DRIFT_INJECTED=true
log "OP3_ARGO_PRODUCT_DRIFT_INJECTED=PASS"

observed_out_of_sync=false
deadline=$((SECONDS + TIMEOUT))
while (( SECONDS < deadline )); do
  sync="$(oc -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
  replicas="$(oc -n "$PAYMENT_NAMESPACE" get deploy "$PRODUCT_DEPLOYMENT" -o jsonpath='{.spec.replicas}' 2>/dev/null || true)"
  [[ "$sync" == "OutOfSync" ]] && observed_out_of_sync=true
  if [[ "$replicas" == "$ORIGINAL_REPLICAS" && "$sync" == "Synced" ]]; then
    break
  fi
  sleep 2
done

replicas="$(oc -n "$PAYMENT_NAMESPACE" get deploy "$PRODUCT_DEPLOYMENT" -o jsonpath='{.spec.replicas}')"
sync="$(oc -n "$ARGO_NAMESPACE" get application "$ARGO_APP" -o jsonpath='{.status.sync.status}')"
[[ "$replicas" == "$ORIGINAL_REPLICAS" && "$sync" == "Synced" ]] || {
  log "Argo CD did not restore Deployment/$PRODUCT_DEPLOYMENT" >&2
  exit 20
}
PRODUCT_DRIFT_INJECTED=false
log "OP3_ARGO_OUTOFSYNC_OBSERVED=$([[ "$observed_out_of_sync" == "true" ]] && echo PASS || echo FAST_HEAL_NOT_SAMPLED)"
log "OP3_ARGO_SELF_HEAL=PASS"

log
log "== Platform drift: Operator reconciliation =="
ORIGINAL_STORAGE="$(oc -n "$PAYMENT_NAMESPACE" get resourcequota "$PLATFORM_QUOTA" -o jsonpath='{.spec.hard.requests\.storage}')"
[[ -n "$ORIGINAL_STORAGE" ]] || {
  log "ResourceQuota/$PLATFORM_QUOTA has no requests.storage hard limit." >&2
  exit 30
}

oc -n "$PAYMENT_NAMESPACE" patch resourcequota "$PLATFORM_QUOTA" --type merge   -p '{"spec":{"hard":{"requests.storage":"99Gi"}}}' >/dev/null
PLATFORM_DRIFT_INJECTED=true
log "OP3_OPERATOR_PLATFORM_DRIFT_INJECTED=PASS"

deadline=$((SECONDS + TIMEOUT))
while (( SECONDS < deadline )); do
  current="$(oc -n "$PAYMENT_NAMESPACE" get resourcequota "$PLATFORM_QUOTA" -o jsonpath='{.spec.hard.requests\.storage}' 2>/dev/null || true)"
  if [[ "$current" == "$ORIGINAL_STORAGE" ]]; then
    break
  fi
  sleep 2
done

current="$(oc -n "$PAYMENT_NAMESPACE" get resourcequota "$PLATFORM_QUOTA" -o jsonpath='{.spec.hard.requests\.storage}')"
[[ "$current" == "$ORIGINAL_STORAGE" ]] || {
  log "Operator did not restore ResourceQuota requests.storage (expected=$ORIGINAL_STORAGE current=$current)" >&2
  exit 31
}
PLATFORM_DRIFT_INJECTED=false
wait_capability_reason Reconciled
log "OP3_OPERATOR_DRIFT_RECOVERY=PASS"

log
log "== Final integrated state =="
wait_jsonpath "application/$ARGO_APP" '{.status.sync.status}' "Synced" "$ARGO_NAMESPACE"
wait_jsonpath "application/$ARGO_APP" '{.status.health.status}' "Healthy" "$ARGO_NAMESPACE"
wait_capability_reason Reconciled

ready="$(oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" -o json | jq -r '.status.conditions[]? | select(.type=="Ready") | [.status,.reason] | @tsv' | tail -n1)"
progressing="$(oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" -o json | jq -r '.status.conditions[]? | select(.type=="Progressing") | [.status,.reason] | @tsv' | tail -n1)"
degraded="$(oc get capabilityconsumption "$CAPABILITY_CONSUMPTION" -o json | jq -r '.status.conditions[]? | select(.type=="Degraded") | [.status,.reason] | @tsv' | tail -n1)"
log "Ready=$ready"
log "Progressing=$progressing"
log "Degraded=$degraded"

log "OP3_FINAL_ARGO_SYNC=PASS"
log "OP3_FINAL_ARGO_HEALTH=PASS"
log "OP3_FINAL_OPERATOR_RECONCILED=PASS"
log "OP3_OPERATOR_ARGO_DAY2_INTEGRATED_DEMO_PROVEN=PASS"
log "truth_boundary=CRC_SINGLE_NODE_NOT_PRODUCTION_HA"
