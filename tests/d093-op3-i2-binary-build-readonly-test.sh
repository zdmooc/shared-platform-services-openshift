#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export D093_EVIDENCE_DIR="$tmp/evidence"
export MOCK_OC_LOG="$tmp/oc.log"

cat > "$tmp/bin/oc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_OC_LOG"
case "$*" in
  "whoami --show-server") echo https://api.crc.testing:6443 ;;
  "-n shared-platform-services get deployment mayabank-platform-operator -o json")
    cat <<'JSON'
{"metadata":{"name":"mayabank-platform-operator"},"status":{"readyReplicas":1,"availableReplicas":1},"spec":{"template":{"spec":{"containers":[{"name":"manager","image":"image-registry.openshift-image-registry.svc:5000/shared-platform-services/mayabank-platform-operator@sha256:ee3c1caed1d27642f11e7491a0e46442a08b0b6cb84df4258c4b7f52a8798d73"}]}}}}
JSON
    ;;
  "get capabilityconsumption instant-payments-crc -o json")
    cat <<'JSON'
{"metadata":{"generation":3},"spec":{"lifecycle":{"adoptionPolicy":"Manage"},"target":{"namespace":"instant-payments-local"}},"status":{"observedGeneration":3,"conditions":[{"type":"Ready","status":"True","reason":"Reconciled"}]}}
JSON
    ;;
  "-n instant-payments-local get resourcequota platform-quota -o json")
    echo '{"spec":{"hard":{"requests.storage":"20Gi"}}}' ;;
  "-n openshift-gitops get application instant-payments-tech-lead-shared-platform -o json")
    echo '{"status":{"sync":{"status":"Synced"},"health":{"status":"Healthy"}}}' ;;
  "-n shared-platform-services get buildconfig d093-op3-ssa-i2 --ignore-not-found -o name") : ;;
  "-n shared-platform-services get imagestreamtag mayabank-platform-operator:crc-i2-ssa-"*" --ignore-not-found -o name") : ;;
  *) echo "Unexpected oc command: $*" >&2; exit 95 ;;
esac
MOCK
chmod +x "$tmp/bin/oc"
export PATH="$tmp/bin:$PATH"

# CI pull-request checkout can be shallow; HEAD contains the revised Go code.
export OP3_I2_SOURCE_SHA="$(git rev-parse HEAD)"
test -n "$OP3_I2_SOURCE_SHA"

# Default must be read-only; no build objects created.
bash "$root/scripts/d093-op3-crc-operator-binary-build.sh" > "$tmp/readonly.log" 2>&1 || {
  cat "$tmp/readonly.log"; exit 1;
}
grep -q 'OP3_I2_BUILD_READONLY=PASS' "$tmp/readonly.log"
! grep -qE '(new-build|start-build|set image|rollout|patch|delete)' "$MOCK_OC_LOG"
: > "$MOCK_OC_LOG"

# Even apply/build mode must refuse mutation without separate consent.
if OP3_I2_MODE=build bash "$root/scripts/d093-op3-crc-operator-binary-build.sh" \
  >"$tmp/no-consent.log" 2>&1; then
  echo "Build mode without authorization was accepted" >&2; exit 1
fi
grep -q 'missing separate binary build authorization token' "$tmp/no-consent.log"
! grep -qE '(new-build|start-build|set image|rollout|patch|delete)' "$MOCK_OC_LOG"
echo "OP3_I2_BUILD_READONLY_MOCK_TEST=PASS"
