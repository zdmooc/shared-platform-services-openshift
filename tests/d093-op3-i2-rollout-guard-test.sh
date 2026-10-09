#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export MOCK_DIR="$tmp"
export D093_EVIDENCE_DIR="$tmp/evidence"
export MOCK_OLD='image-registry.openshift-image-registry.svc:5000/shared-platform-services/mayabank-platform-operator@sha256:ee3c1caed1d27642f11e7491a0e46442a08b0b6cb84df4258c4b7f52a8798d73'
export MOCK_NEW='image-registry.openshift-image-registry.svc:5000/shared-platform-services/mayabank-platform-operator@sha256:acfa316265a0c3466a67dfecc1b731ae6a7bed78689dbe39a14bdad10d80d3a1'
printf '%s' "$MOCK_OLD" > "$tmp/image"

cat > "$tmp/bin/oc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
args="$*"
printf '%s\n' "$args" >> "$MOCK_DIR/oc.log"
case "$args" in
  "whoami --show-server") echo https://api.crc.testing:6443 ;;
  "-n shared-platform-services get deployment mayabank-platform-operator -o json")
    current="$(cat "$MOCK_DIR/image")"
    cat <<JSON
{"metadata":{"name":"mayabank-platform-operator","generation":3},
 "status":{"readyReplicas":1,"availableReplicas":1,"updatedReplicas":1,"observedGeneration":3},
 "spec":{"replicas":1,"strategy":{"type":"RollingUpdate"},
 "template":{"spec":{"serviceAccountName":"mayabank-platform-operator",
 "containers":[{"name":"manager","image":"$current"}]}}}}
JSON
    ;;
  "-n shared-platform-services get build d093-op3-ssa-i2-1 -o json")
    echo '{"status":{"phase":"Complete"},"spec":{"output":{"to":{"kind":"ImageStreamTag","name":"mayabank-platform-operator:crc-i2-ssa-91e99136add2"}}}}' ;;
  "-n shared-platform-services get imagestreamtag mayabank-platform-operator:crc-i2-ssa-91e99136add2 -o json")
    echo '{"image":{"dockerImageReference":"'"$MOCK_NEW"'"}}' ;;
  "get capabilityconsumption instant-payments-crc -o json")
    echo '{"metadata":{"generation":3},"status":{"observedGeneration":3,"conditions":[{"type":"Ready","status":"True","reason":"Reconciled"}]},"spec":{"lifecycle":{"adoptionPolicy":"Manage","deletionPolicy":"Retain"},"target":{"namespace":"instant-payments-local"}}}' ;;
  "-n instant-payments-local get resourcequota platform-quota -o json")
    echo '{"metadata":{"labels":{"platform.mayabank.example/managed-by":"mayabank-platform-operator","platform.mayabank.example/consumption":"instant-payments-crc"}},"spec":{"hard":{"requests.storage":"20Gi"}}}' ;;
  "-n instant-payments-local get deployment wero-ui -o json")
    echo '{"spec":{"replicas":1},"status":{"availableReplicas":1}}' ;;
  "-n openshift-gitops get application instant-payments-tech-lead-shared-platform -o json")
    echo '{"status":{"sync":{"status":"Synced"},"health":{"status":"Healthy"}}}' ;;
  "auth can-i patch deployments.apps -n shared-platform-services") echo yes ;;
  "-n shared-platform-services set image deployment/mayabank-platform-operator manager="*)
    image="${args##*manager=}"
    printf '%s' "$image" > "$MOCK_DIR/image" ;;
  "-n shared-platform-services rollout status deployment/mayabank-platform-operator --timeout="*)
    current="$(cat "$MOCK_DIR/image")"
    if [[ "${MOCK_FAIL_NEW:-false}" == "true" && "$current" == "$MOCK_NEW" ]]; then
      echo 'mock rollout failure' >&2
      exit 89
    fi
    echo 'mock rollout success' ;;
  *) echo "UNEXPECTED OC: $args" >&2; exit 99 ;;
esac
MOCK
chmod +x "$tmp/bin/oc"
export PATH="$tmp/bin:$PATH"
script="$root/scripts/d093-op3-crc-operator-rollout.sh"

# 1. Readonly default never mutates any Deployment.
bash "$script" > "$tmp/readonly.out" 2>&1 || {
  cat "$tmp/readonly.out"; exit 1;
}
grep -q 'OP3_I2_ROLLOUT_READONLY=PASS' "$tmp/readonly.out"
! grep -Eq '(set image|rollout status)' "$tmp/oc.log"
: > "$tmp/oc.log"

# 2. Opt-in mode without the consent token fails before mutation.
if OP3_I2_ROLLOUT_MODE=apply bash "$script" > "$tmp/no-consent.out" 2>&1; then
  echo 'Expected consent refusal' >&2; exit 1
fi
! grep -Eq '(set image|rollout status)' "$tmp/oc.log"
: > "$tmp/oc.log"

# 3. Authorized and healthy rollout changes manager image once.
OP3_I2_ROLLOUT_MODE=apply \
  CONFIRM_OP3_I2_CRC_ROLLOUT=YES_I_AUTHORIZE_CRC_OPERATOR_IMAGE_ROLLOUT \
  bash "$script" > "$tmp/apply.out" 2>&1 || {
  cat "$tmp/apply.out"; exit 1;
}
grep -q 'OP3_I2_OPERATOR_NEW_IMAGE_RUNTIME=PASS' "$tmp/apply.out"
[[ "$(cat "$tmp/image")" == "$MOCK_NEW" ]]

# 4. Rollout failure must restore old image and report rollback.
printf '%s' "$MOCK_OLD" > "$tmp/image"
: > "$tmp/oc.log"
set +e
MOCK_FAIL_NEW=true OP3_I2_ROLLOUT_MODE=apply \
  CONFIRM_OP3_I2_CRC_ROLLOUT=YES_I_AUTHORIZE_CRC_OPERATOR_IMAGE_ROLLOUT \
  bash "$script" > "$tmp/fail.out" 2>&1
status=$?
set -e
if [[ "$status" -eq 0 ]]; then
  cat "$tmp/fail.out"
  echo 'Expected failure when rollout fails' >&2
  exit 1
fi
grep -q 'OP3_I2_ROLLBACK=PASS_OLD_IMAGE_RESTORED' "$tmp/fail.out" || {
  cat "$tmp/fail.out"; exit 1;
}
[[ "$(cat "$tmp/image")" == "$MOCK_OLD" ]]
echo 'OP3_I2_ROLLOUT_GUARD_MOCK_TEST=PASS'
