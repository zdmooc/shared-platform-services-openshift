#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

NAMESPACE="${KEYCLOAK_NAMESPACE:-keycloak-system}"
KEYCLOAK_CR="${KEYCLOAK_CR:-keycloak}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.apps-crc.testing}"
REALM="${SHARED_REALM:-mayabank}"

command -v oc >/dev/null 2>&1 || { echo "oc CLI is required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
command -v python >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required"; exit 1; }

PYTHON_BIN="$(command -v python3 || command -v python)"

if ! oc api-resources --api-group=config.openshift.io --no-headers 2>/dev/null | grep -qE '^clusterversions[[:space:]]'; then
  echo "ERROR: current context is not OpenShift/CRC"
  exit 2
fi

oc -n "${NAMESPACE}" get keycloak "${KEYCLOAK_CR}" >/dev/null
oc -n "${NAMESPACE}" wait --for=condition=Ready "keycloak/${KEYCLOAK_CR}" --timeout=60s
oc -n "${NAMESPACE}" get svc "${KEYCLOAK_CR}-service" >/dev/null

ADMIN_SECRET="${KEYCLOAK_ADMIN_SECRET:-keycloak-initial-admin}"
ADMIN_USER="$(oc -n "${NAMESPACE}" get secret "${ADMIN_SECRET}" -o jsonpath='{.data.username}' | base64 -d)"
ADMIN_PASSWORD="$(oc -n "${NAMESPACE}" get secret "${ADMIN_SECRET}" -o jsonpath='{.data.password}' | base64 -d)"

test -n "${ADMIN_USER}"
test -n "${ADMIN_PASSWORD}"

for _ in $(seq 1 60); do
  if curl -kfsS "${KEYCLOAK_URL}/realms/master/.well-known/openid-configuration" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

ADMIN_TOKEN="$(curl -kfsS -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'client_id=admin-cli' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode "username=${ADMIN_USER}" \
  --data-urlencode "password=${ADMIN_PASSWORD}" | "${PYTHON_BIN}" -c 'import json,sys; print(json.load(sys.stdin).get("access_token",""))')"

test -n "${ADMIN_TOKEN}"

status="$(curl -ksS -o /tmp/shared-realm.json -w '%{http_code}' \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}")"

if [[ "${status}" == "404" ]]; then
  create_code="$(curl -ksS -o /tmp/shared-realm-create.out -w '%{http_code}' \
    -X POST "${KEYCLOAK_URL}/admin/realms" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H 'Content-Type: application/json' \
    --data-binary @platform/identity/keycloak/mayabank-realm.json)"
  test "${create_code}" = "201"
elif [[ "${status}" != "200" ]]; then
  echo "ERROR: realm lookup failed with HTTP ${status}" >&2
  exit 1
fi

curl -kfsS "${KEYCLOAK_URL}/realms/${REALM}/.well-known/openid-configuration" >/tmp/shared-oidc-discovery.json
"${PYTHON_BIN}" - <<'PY'
import json
from pathlib import Path
obj=json.loads(Path("/tmp/shared-oidc-discovery.json").read_text())
assert obj["issuer"].endswith("/realms/mayabank")
assert obj.get("jwks_uri")
PY

unset ADMIN_TOKEN ADMIN_USER ADMIN_PASSWORD
rm -f /tmp/shared-realm.json /tmp/shared-realm-create.out /tmp/shared-oidc-discovery.json

echo "SHARED_KEYCLOAK_REALM=PASS"
echo "SHARED_OIDC_DISCOVERY=PASS"
echo "claim=CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN only after this output is observed and evidence is retained"
