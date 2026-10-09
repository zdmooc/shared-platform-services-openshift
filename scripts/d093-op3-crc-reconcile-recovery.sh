#!/usr/bin/env bash
set -euo pipefail

# D-093 OP3: one bounded requeue of the already adopted Instant Payments
# CapabilityConsumption. No cluster or operator restart, no spec changes.
log() { printf '%s\n' "$*"; }
die() { log "ERROR: $*" >&2; exit 1; }

for tool in oc jq date; do
  command -v "$tool" >/dev/null || die "Missing required tool: $tool"
done

mode="$(printenv OP3_RECOVERY_MODE || true)"
[ -n "$mode" ] || mode=readonly
case "$mode" in
  readonly|apply) ;;
  *) die "OP3_RECOVERY_MODE must be readonly or apply" ;;
esac

api="$(oc whoami --show-server)"
[ "$api" = "https://api.crc.testing:6443" ] || die "Refusing non-CRC cluster: $api"

evidence="$(printenv D093_EVIDENCE_DIR || true)"
[ -n "$evidence" ] || evidence="$(mktemp -d)"
mkdir -p "$evidence"
log "OP3_RECOVERY_EVIDENCE_DIR=$evidence"

cc=instant-payments-crc
namespace=instant-payments-local
operator_ns=shared-platform-services
operator_name=mayabank-platform-operator
argo_app=instant-payments-tech-lead-shared-platform
annotation=platform.mayabank.example/d093-reconcile-request

# Snapshot only the scoped consumer, platform objects and product Deployment.
oc get capabilityconsumption "$cc" -o json > "$evidence/consumer-before.json"
jq -e '
  .metadata.name == "instant-payments-crc"
  and .spec.consumer.name == "instant-payments"
  and .spec.consumer.environment == "crc"
  and .spec.target.namespace == "instant-payments-local"
  and .spec.lifecycle.adoptionPolicy == "Manage"
  and .spec.lifecycle.deletionPolicy == "Retain"
' "$evidence/consumer-before.json" >/dev/null ||
  die "Unexpected consumer target/adoption/deletion policy; no mutation"

oc -n "$operator_ns" get deployment "$operator_name" -o json |
  jq -e '(.status.readyReplicas // 0) >= 1 and (.status.availableReplicas // 0) >= 1' >/dev/null ||
  die "Direct Platform Operator unavailable"

oc -n openshift-pipelines get endpointslice \
  -l kubernetes.io/service-name=tekton-operator-proxy-webhook -o json |
  jq -e 'any(.items[].endpoints[]?;
    .conditions.ready == true
    and .conditions.serving == true
    and .conditions.terminating != true)' >/dev/null ||
  die "Tekton webhook has no ready/serving nonterminating endpoint"

oc -n openshift-gitops get application "$argo_app" -o json |
  jq -e '.status.sync.status == "Synced" and .status.health.status == "Healthy"' >/dev/null ||
  die "Instant Payments Argo CD application is not Synced/Healthy"

oc -n "$namespace" get resourcequota,limitrange,networkpolicy,serviceaccount,role,rolebinding \
  -o json > "$evidence/platform-baseline-before.json"
oc -n "$namespace" get deployment/wero-ui -o json > "$evidence/wero-ui-before.json"

log "OP3_RECOVERY_PREFLIGHT=PASS"
jq -r '.status.conditions[]? | select(.type == "Ready") |
  "OP3_RECOVERY_INITIAL_READY=\(.status)/\(.reason): \(.message)"' "$evidence/consumer-before.json"

if [ "$mode" = "readonly" ]; then
  log "OP3_RECOVERY_READONLY=PASS"
  log "No CapabilityConsumption annotation/spec or managed platform resource changed."
  exit 0
fi

[ "$(printenv CONFIRM_OP3_CRC_RECONCILE || true)" = "YES_I_AUTHORIZE_INSTANT_PAYMENTS_PLATFORM_RECONCILE" ] ||
  die "Separate explicit consent token required for Apply/Manage reconciliation"

if jq -e 'any(.status.conditions[]?;
  .type == "Ready" and .status == "True" and .reason == "Reconciled")' \
  "$evidence/consumer-before.json" >/dev/null; then
  log "OP3_RECOVERY_ALREADY_RECONCILED=PASS"
  log "No annotation changed."
  exit 0
fi

limit="$(printenv OP3_RECOVERY_TIMEOUT_SECONDS || true)"
[ -n "$limit" ] || limit=120
case "$limit" in
  *[!0-9]*|"") die "Invalid timeout" ;;
esac
[ "$limit" -ge 10 ] && [ "$limit" -le 300 ] || die "Timeout must be 10..300 seconds"

# An annotation-only update to exactly one existing CR enqueues the controller.
# No direct patch of product Deployment, quota, Tekton or the operator itself.
jq -e --arg k "$annotation" '(.metadata.annotations[$k] // null) == null' \
  "$evidence/consumer-before.json" >/dev/null ||
  die "Recovery annotation already exists; refuse to overwrite"

rv="$(jq -r '.metadata.resourceVersion // empty' "$evidence/consumer-before.json")"
[ -n "$rv" ] || die "Consumer resourceVersion absent"

nonce="$(date -u +%Y%m%dT%H%M%SZ)"
log "OP3_RECOVERY_MUTATION_SCOPE=CapabilityConsumption/$cc metadata.annotation only"
log "OP3_RECOVERY_IMPACT=Operator may reapply platform namespace/RBAC/quota/limits/network policies in Manage mode"
oc annotate capabilityconsumption "$cc" "$annotation=$nonce" --resource-version="$rv" >/dev/null
log "OP3_RECOVERY_ANNOTATION_APPLIED=PASS"

deadline=$((SECONDS + limit))

while (( SECONDS < deadline )); do
  oc get capabilityconsumption "$cc" -o json > "$evidence/consumer-after.json" || true
  if jq -e '
    .metadata.generation == .status.observedGeneration
    and any(.status.conditions[]?; .type == "Ready" and .status == "True" and .reason == "Reconciled")
    and any(.status.managedResources[]?; .kind == "ResourceQuota")
    and all(.status.managedResources[]?; .kind != "Deployment")
  ' "$evidence/consumer-after.json" >/dev/null 2>&1; then
    oc -n "$namespace" get resourcequota,limitrange,networkpolicy,serviceaccount,role,rolebinding \
      -o json > "$evidence/platform-baseline-after.json"
    oc -n "$namespace" get deployment/wero-ui -o json > "$evidence/wero-ui-after.json"
    log "OP3_RECOVERY_RECONCILED=PASS"
    log "OP3_RECOVERY_SCOPE=CRC_CONSUMER1_ONLY"
    log "truth_boundary=RECONCILIATION_RECOVERY_NOT_OP3_DAY2_DRIFT_PROOF"
    exit 0
  fi
  sleep 3
done

log "OP3_RECOVERY_RECONCILED=BLOCKED"
if [ -f "$evidence/consumer-after.json" ]; then
  jq -r '.status.conditions[]? | select(.type=="Ready") |
    "Ready=\(.status) reason=\(.reason) message=\(.message)"' \
    "$evidence/consumer-after.json" || true
fi
log "No automatic rollback of CR annotation: reverting it can retrigger Manage."
log "Investigate operator logs and preserve snapshots before further actions."
exit 42
