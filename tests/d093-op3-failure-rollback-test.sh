#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export OP3_ROLLBACK_MOCK_DIR="$tmp"
echo 20Gi > "$tmp/storage"

cat > "$tmp/bin/oc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
printf '%s\n' "$args" >>"$OP3_ROLLBACK_MOCK_DIR/oc.log"

case "$args" in
  "whoami") echo kubeadmin ;;
  "whoami --show-server") echo https://api.crc.testing:6443 ;;
  "get clusterversion") echo 'version 4.22.7' ;;
  "api-resources") echo 'applications app argoproj.io/v1alpha1 true Application' ;;
  "-n openshift-gitops get application instant-payments-tech-lead-shared-platform"|"get capabilityconsumption instant-payments-crc"|"-n instant-payments-local get deploy wero-ui"|"-n instant-payments-local get resourcequota platform-quota")
    echo exists ;;
  *"get application/instant-payments-tech-lead-shared-platform -o jsonpath={.status.sync.status}"|*"get application instant-payments-tech-lead-shared-platform -o jsonpath={.status.sync.status}") echo Synced ;;
  *"get application/instant-payments-tech-lead-shared-platform -o jsonpath={.status.health.status}"|*"get application instant-payments-tech-lead-shared-platform -o jsonpath={.status.health.status}") echo Healthy ;;
  "get capabilityconsumption instant-payments-crc -o jsonpath={.spec.lifecycle.adoptionPolicy}") echo Manage ;;
  "get capabilityconsumption instant-payments-crc -o json")
    echo '{"status":{"managedResources":[{"kind":"ResourceQuota"},{"kind":"Namespace"}],"conditions":[{"type":"Ready","status":"True","reason":"Reconciled"},{"type":"Progressing","status":"False","reason":"Stable"},{"type":"Degraded","status":"False","reason":"Healthy"}]}}' ;;
  *"get application instant-payments-tech-lead-shared-platform -o json")
    echo '{"status":{"resources":[{"kind":"Deployment","namespace":"instant-payments-local","name":"wero-ui"}]}}' ;;
  *"get deploy wero-ui -o jsonpath={.spec.replicas}") echo 1 ;;
  *"get deploy wero-ui -o jsonpath={.status.availableReplicas}") echo 1 ;;
  *"get resourcequota platform-quota -o jsonpath="*) cat "$OP3_ROLLBACK_MOCK_DIR/storage" ;;
  *"patch deploy wero-ui --type merge"*) echo patched ;;
  *"patch resourcequota platform-quota --type merge"*)
    if [[ "$args" == *'99Gi'* ]]; then
      echo 99Gi > "$OP3_ROLLBACK_MOCK_DIR/storage"
    elif [[ "$args" == *'20Gi'* ]]; then
      if [[ -e "$OP3_ROLLBACK_MOCK_DIR/deny-rollback" ]]; then
        echo "mock rollback denied" >&2
        exit 88
      fi
      echo 20Gi > "$OP3_ROLLBACK_MOCK_DIR/storage"
    else
      echo "Unexpected storage patch: $args" >&2
      exit 89
    fi ;;
  *"get deployment/wero-ui resourcequota/platform-quota -o wide") echo diagnostics ;;
  *) echo "unexpected oc: $args" >&2; exit 90 ;;
esac
MOCK
chmod +x "$tmp/bin/oc"

run_case() {
  local expected="$1" marker="$2"
  echo 20Gi > "$tmp/storage"
  : > "$tmp/oc.log"
  set +e
  PATH="$tmp/bin:$PATH" TIMEOUT_SECONDS=2 OP3_PREFLIGHT_ONLY=false \
    CONFIRM_OP3_CRC_DRIFT=YES_I_AUTHORIZE_OP3_CONTROLLED_DRIFT \
    bash "$repo/scripts/d093-op3-operator-argocd-day2.sh" > "$tmp/output.log" 2>&1
  local status=$?
  set -e
  if [[ "$status" -ne "$expected" ]] || ! grep -q "$marker" "$tmp/output.log"; then
    cat "$tmp/output.log"
    cat "$tmp/oc.log"
    echo "Expected status=$expected and marker=$marker, observed status=$status" >&2
    exit 1
  fi
  ! grep -q 'OP3_OPERATOR_ARGO_DAY2_INTEGRATED_DEMO_PROVEN=PASS' "$tmp/output.log"
}

# Simulated Operator quota repair times out; the trap restores the quota.
run_case 31 'OP3_QUOTA_ROLLBACK=PASS requests.storage=20Gi'
[[ "$(cat "$tmp/storage")" == "20Gi" ]]
grep -q 'truth_boundary=MANUAL_ROLLBACK_NOT_OPERATOR_SELF_HEAL' "$tmp/output.log"

# Failed rollback must be unambiguously reported with a distinct error.
touch "$tmp/deny-rollback"
run_case 86 'OP3_ROLLBACK_ATTENTION_REQUIRED=YES'
[[ "$(cat "$tmp/storage")" == "99Gi" ]]
grep -q 'OP3_QUOTA_ROLLBACK=FAILED patch error' "$tmp/output.log"
echo 'OP3_ROLLBACK_REPORTING_MOCK_TEST=PASS'
