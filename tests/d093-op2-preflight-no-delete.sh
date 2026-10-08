#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/bin"

cat >"$TEST_DIR/bin/oc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$OP2_OC_LOG"
case "$*" in
  whoami) echo fake-admin ;;
  "get clusterversion") echo 'version 4.22.7' ;;
  "version -o json") echo '{"openshiftVersion":"4.22.7"}' ;;
  api-resources) printf 'ClusterServiceVersion\nSubscription\nOperatorGroup\nCatalogSource\n' ;;
  "image info "*) exit 0 ;;
  "get namespace d093-op2-olm")
    [[ "$OP2_TEST_SCENARIO" == existing_namespace ]] && exit 0 || exit 1 ;;
  "get namespace d093-op2-consumer") exit 1 ;;
  "get capabilityconsumption d093-op2-olm-consumer")
    [[ "$OP2_TEST_SCENARIO" == existing_cr ]] && exit 0 || exit 1 ;;
  *) exit 0 ;;
esac
MOCK

cat >"$TEST_DIR/bin/jq" <<'MOCK'
#!/usr/bin/env bash
cat >/dev/null || true
echo '4.22.7'
MOCK

cat >"$TEST_DIR/bin/operator-sdk" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$TEST_DIR/bin/"*

for scenario in existing_namespace existing_cr; do
  log="$TEST_DIR/$scenario-oc.log"
  : >"$log"
  set +e
  PATH="$TEST_DIR/bin:$PATH" OP2_OC_LOG="$log" OP2_TEST_SCENARIO="$scenario" \
    bash "$ROOT_DIR/scripts/d093-op2-olm-crc.sh" >"$TEST_DIR/$scenario.log" 2>&1
  rc=$?
  set -e
  expected=20
  [[ "$scenario" == existing_cr ]] && expected=22
  if [[ "$rc" != "$expected" ]]; then
    cat "$TEST_DIR/$scenario.log"
    echo "Expected preflight exit $expected for $scenario, got $rc" >&2
    exit 1
  fi
  if grep -Eq '^(delete|scale|create|apply|patch)( |$)' "$log"; then
    cat "$log"
    echo "Unsafe mutation attempted during $scenario preflight" >&2
    exit 1
  fi
  echo "OP2_PREFLIGHT_NO_MUTATION_${scenario^^}=PASS"
done

echo 'OP2_FAILED_PREFLIGHT_CLEANUP_GUARD=PASS'
