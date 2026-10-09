#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin"
export OP3_OC_LOG="$TEST_DIR/oc.log"

cat >"$TEST_DIR/bin/oc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$OP3_OC_LOG"
case "$*" in
  "whoami") echo fake-admin ;;
  "whoami --show-server") echo https://api.crc.testing:6443 ;;
  "get clusterversion") echo "version 4.22.7" ;;
  "api-resources") echo "applications app argoproj.io/v1alpha1 true Application" ;;
  *".status.sync.status"*) echo Synced ;;
  *".status.health.status"*) echo Healthy ;;
  "get capabilityconsumption instant-payments-crc -o json")
    echo '{"metadata":{"generation":3},"status":{"conditions":[{"type":"Ready","status":"False","reason":"ApplyFailed","lastTransitionTime":"2026-10-05T14:01:18Z","message":"no endpoints available for service tekton-operator-proxy-webhook"}]}}' ;;
  "-n shared-platform-services get deploy/mayabank-platform-operator -o wide") echo 'mayabank-platform-operator 1/1' ;;
  "-n openshift-pipelines get endpoints/tekton-operator-proxy-webhook -o wide") echo 'tekton-operator-proxy-webhook <none>' ;;
  "-n openshift-gitops get application instant-payments-tech-lead-shared-platform"|"get capabilityconsumption instant-payments-crc"|"-n instant-payments-local get deploy wero-ui"|"-n instant-payments-local get resourcequota platform-quota") echo mock-ok ;;
  *) echo "Unexpected oc request: $*" >&2; exit 64 ;;
esac
MOCK
chmod +x "$TEST_DIR/bin/oc"

set +e
PATH="$TEST_DIR/bin:$PATH" OP3_PREFLIGHT_ONLY=true TIMEOUT_SECONDS=2 \
  bash "$ROOT_DIR/scripts/d093-op3-operator-argocd-day2.sh" >"$TEST_DIR/output.log" 2>&1
status=$?
set -e

if [[ "$status" -ne 32 ]]; then
  cat "$TEST_DIR/output.log"
  cat "$OP3_OC_LOG"
  echo "Expected blocked status 32, got $status" >&2
  exit 1
fi
grep -q 'OP3_PREFLIGHT_BLOCKED=OPERATOR_NOT_RECONCILED' "$TEST_DIR/output.log"
grep -q 'OP3_EXIT_WITHOUT_MUTATION=PASS' "$TEST_DIR/output.log"

if grep -Eq '^(patch|apply|delete|create|scale)( |$)' "$OP3_OC_LOG"; then
  cat "$OP3_OC_LOG"
  echo "OP3 preflight attempted to mutate resources" >&2
  exit 1
fi
if grep -Eq 'last-applied-configuration:|apiVersion: argoproj.io/v1alpha1' "$TEST_DIR/output.log"; then
  echo "OP3 diagnostic output unexpectedly dumped full resource YAML" >&2
  exit 1
fi
echo 'OP3_READONLY_BLOCKER_NO_MUTATION=PASS'
