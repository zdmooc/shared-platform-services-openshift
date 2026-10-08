#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
export OP3_MOCK_LOG="$WORK/oc.log"
export OP3_MOCK_STORAGE=20Gi OP3_MOCK_REPLICAS=1 OP3_MOCK_AVAILABLE=1

cat > "$WORK/bin/oc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$OP3_MOCK_LOG"
case "$*" in
  "whoami") echo kubeadmin ;;
  "whoami --show-server") echo https://api.crc.testing:6443 ;;
  "get clusterversion") echo "version 4.22.7" ;;
  "api-resources") echo "applications app argoproj.io/v1alpha1 true Application" ;;
  *"get application instant-payments-tech-lead-shared-platform -o jsonpath={.status.sync.status}") echo Synced ;;
  *"get application instant-payments-tech-lead-shared-platform -o jsonpath={.status.health.status}") echo Healthy ;;
  "get capabilityconsumption instant-payments-crc -o jsonpath={.spec.lifecycle.adoptionPolicy}") echo Manage ;;
  "get capabilityconsumption instant-payments-crc -o json")
    echo '{"status":{"conditions":[{"type":"Ready","status":"True","reason":"Reconciled"}],"managedResources":[{"kind":"Namespace"},{"kind":"ResourceQuota"}]}}' ;;
  *"get application instant-payments-tech-lead-shared-platform -o json")
    echo '{"status":{"resources":[{"kind":"Deployment","namespace":"instant-payments-local","name":"wero-ui"}]}}' ;;
  *"get deploy wero-ui -o jsonpath={.spec.replicas}") echo "$OP3_MOCK_REPLICAS" ;;
  *"get deploy wero-ui -o jsonpath={.status.availableReplicas}") echo "$OP3_MOCK_AVAILABLE" ;;
  *"get resourcequota platform-quota -o jsonpath={.spec.hard.requests\\.storage}") echo "$OP3_MOCK_STORAGE" ;;
  "-n openshift-gitops get application instant-payments-tech-lead-shared-platform"|"get capabilityconsumption instant-payments-crc"|"-n instant-payments-local get deploy wero-ui"|"-n instant-payments-local get resourcequota platform-quota")
    echo mock-ok ;;
  *) echo "Unexpected oc invocation: $*" >&2; exit 90 ;;
esac
MOCK
chmod +x "$WORK/bin/oc"

case_run() {
  local scenario="$1" expected="$2"
  : > "$OP3_MOCK_LOG"
  set +e
  PATH="$WORK/bin:$PATH" CONFIRM_OP3_CRC_DRIFT=YES_I_AUTHORIZE_OP3_CONTROLLED_DRIFT \
    TIMEOUT_SECONDS=2 bash "$ROOT_DIR/scripts/d093-op3-operator-argocd-day2.sh" > "$WORK/$scenario.log" 2>&1
  local result=$?
  set -e
  if [[ "$result" -ne "$expected" ]]; then
    cat "$WORK/$scenario.log"
    cat "$OP3_MOCK_LOG"
    echo "Expected exit $expected; got $result in $scenario" >&2
    exit 1
  fi
  grep -q 'OP3_DRIFT_REFUSED:' "$WORK/$scenario.log"
  ! grep -Eq '(^| )(patch|apply|delete|create|scale|rollout)( |$)' "$OP3_MOCK_LOG"
}

OP3_MOCK_STORAGE=19Gi case_run unexpected-quota 42
OP3_MOCK_REPLICAS=2 case_run unexpected-replicas 41
OP3_MOCK_AVAILABLE=0 case_run unavailable-product 41
echo "OP3_DRIFT_BASELINE_FAIL_CLOSED=PASS"
