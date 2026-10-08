#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export MOCK_DIR="$tmp"
export PATH="$tmp/bin:$PATH"
export D093_EVIDENCE_DIR="$tmp/evidence"

cat >"$tmp/bin/oc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "$MOCK_DIR/oc.log"
case "$*" in
  "whoami --show-server")
    if [ -f "$MOCK_DIR/wrong-server" ]; then
      echo https://api.not-crc.example:6443
    else
      echo https://api.crc.testing:6443
    fi ;;
  "get capabilityconsumption instant-payments-crc -o json")
    if [ -f "$MOCK_DIR/annotated" ]; then
      cat "$MOCK_DIR/cc-success.json"
    else
      cat "$MOCK_DIR/cc-failed.json"
    fi ;;
  "-n shared-platform-services get deployment mayabank-platform-operator -o json")
    echo '{"status":{"readyReplicas":1,"availableReplicas":1}}' ;;
  "-n openshift-pipelines get endpointslice -l kubernetes.io/service-name=tekton-operator-proxy-webhook -o json")
    if [ -f "$MOCK_DIR/webhook-failed" ]; then
      echo '{"items":[{"endpoints":[{"conditions":{"ready":false,"serving":false,"terminating":false}}]}]}'
    else
      echo '{"items":[{"endpoints":[{"conditions":{"ready":true,"serving":true,"terminating":false}}]}]}'
    fi ;;
  "-n openshift-gitops get application instant-payments-tech-lead-shared-platform -o json")
    echo '{"status":{"sync":{"status":"Synced"},"health":{"status":"Healthy"}}}' ;;
  "-n instant-payments-local get resourcequota,limitrange,networkpolicy,serviceaccount,role,rolebinding -o json")
    echo '{"items":[]}' ;;
  "-n instant-payments-local get deployment/wero-ui -o json")
    echo '{"kind":"Deployment","metadata":{"name":"wero-ui"}}' ;;
  "annotate capabilityconsumption instant-payments-crc platform.mayabank.example/d093-reconcile-request="*" --resource-version=100")
    touch "$MOCK_DIR/annotated" ;;
  *) echo "unexpected oc: $*" >&2; exit 80 ;;
esac
MOCK
chmod +x "$tmp/bin/oc"

cat > "$tmp/cc-failed.json" <<'JSON'
{
  "metadata":{"name":"instant-payments-crc","resourceVersion":"100","generation":3},
  "spec":{"consumer":{"name":"instant-payments","environment":"crc"},"target":{"namespace":"instant-payments-local"},"lifecycle":{"adoptionPolicy":"Manage","deletionPolicy":"Retain"}},
  "status":{"observedGeneration":3,"conditions":[{"type":"Ready","status":"False","reason":"ApplyFailed","message":"old webhook error"}]}
}
JSON
cat > "$tmp/cc-success.json" <<'JSON'
{
  "metadata":{"name":"instant-payments-crc","resourceVersion":"101","generation":3},
  "spec":{"consumer":{"name":"instant-payments","environment":"crc"},"target":{"namespace":"instant-payments-local"},"lifecycle":{"adoptionPolicy":"Manage","deletionPolicy":"Retain"}},
  "status":{"observedGeneration":3,"conditions":[{"type":"Ready","status":"True","reason":"Reconciled","message":"healthy"}],"managedResources":[{"kind":"ResourceQuota"}]}
}
JSON

target="$root/scripts/d093-op3-crc-reconcile-recovery.sh"

# 1. Default mode is always read-only.
bash "$target" > "$tmp/readonly.log" 2>&1
grep -q 'OP3_RECOVERY_READONLY=PASS' "$tmp/readonly.log"
! grep -q '^annotate ' "$tmp/oc.log"
rm -f "$tmp/oc.log"

# 2. Failing webhook must stop before any annotation.
touch "$tmp/webhook-failed"
if OP3_RECOVERY_MODE=apply CONFIRM_OP3_CRC_RECONCILE=YES_I_AUTHORIZE_INSTANT_PAYMENTS_PLATFORM_RECONCILE \
  bash "$target" > "$tmp/webhook.log" 2>&1; then
  echo "Expected webhook fail-closed" >&2; exit 1
fi
! grep -q '^annotate ' "$tmp/oc.log"
rm -f "$tmp/webhook-failed" "$tmp/oc.log"

# 3. Apply without consent must fail before annotation.
if OP3_RECOVERY_MODE=apply bash "$target" > "$tmp/no-consent.log" 2>&1; then
  echo "Expected consent fail-closed" >&2; exit 1
fi
! grep -q '^annotate ' "$tmp/oc.log"
rm -f "$tmp/oc.log"

# 4. Wrong API must fail before consumer access.
touch "$tmp/wrong-server"
if bash "$target" > "$tmp/wrong-server.log" 2>&1; then
  echo "Expected CRC context fail-closed" >&2; exit 1
fi
! grep -q '^get capabilityconsumption' "$tmp/oc.log"
rm -f "$tmp/wrong-server" "$tmp/oc.log"

# 5. Explicit authorized apply changes annotation ONLY on the scoped CR.
OP3_RECOVERY_MODE=apply \
  CONFIRM_OP3_CRC_RECONCILE=YES_I_AUTHORIZE_INSTANT_PAYMENTS_PLATFORM_RECONCILE \
  OP3_RECOVERY_TIMEOUT_SECONDS=10 bash "$target" > "$tmp/apply.log" 2>&1
grep -q 'OP3_RECOVERY_RECONCILED=PASS' "$tmp/apply.log"
[ "$(grep -c '^annotate ' "$tmp/oc.log")" -eq 1 ]
if grep -Eq '^(patch|apply|delete|create|scale|rollout)( |$)' "$tmp/oc.log"; then
  echo "Unexpected mutation" >&2; exit 1
fi
echo "OP3_RECOVERY_MOCK_TEST=PASS"
