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
  "whoami --show-server") echo 'https://api.crc.testing:6443' ;;
  "get clusterversion") echo 'version 4.22.7' ;;
  "version -o json") echo '{"openshiftVersion":"4.22.7"}' ;;
  api-resources)
    printf 'ClusterServiceVersion\nSubscription\nOperatorGroup\n'
    [[ "$OP2_TEST_SCENARIO" == missing_api ]] ||
      printf 'CatalogSource\n'
    if [[ "$OP2_TEST_SCENARIO" == large_api_output ]]; then
      # Original use of grep -q could SIGPIPE a large oc discovery response.
      awk 'BEGIN{for(i=0;i<20000;i++) print "synthetic-api-resource"}'
    fi
    ;;
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

for scenario in existing_namespace existing_cr read_only unauthorized large_api_output missing_api; do
  log="$TEST_DIR/$scenario-oc.log"
  : >"$log"
  set +e
  PATH="$TEST_DIR/bin:$PATH" OP2_OC_LOG="$log" OP2_TEST_SCENARIO="$scenario" \
    OP2_PREFLIGHT_ONLY=$([[ "$scenario" == read_only || "$scenario" == large_api_output || "$scenario" == missing_api ]] && echo true || echo false) \
    bash "$ROOT_DIR/scripts/d093-op2-olm-crc.sh" >"$TEST_DIR/$scenario.log" 2>&1
  rc=$?
  set -e
  expected=20
  [[ "$scenario" == existing_cr ]] && expected=22
  [[ "$scenario" == read_only || "$scenario" == large_api_output ]] && expected=0
  [[ "$scenario" == missing_api ]] && expected=24
  [[ "$scenario" == unauthorized ]] && expected=23
  if [[ "$rc" != "$expected" ]]; then
    cat "$TEST_DIR/$scenario.log"
    echo "Expected preflight exit $expected for $scenario, got $rc" >&2
    exit 1
  fi
  if [[ "$scenario" == missing_api ]] &&
     ! grep -q 'OP2_OLM_API_MISSING=CatalogSource' "$TEST_DIR/$scenario.log"; then
    cat "$TEST_DIR/$scenario.log"
    echo 'Missing precise OLM API failure marker' >&2
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
