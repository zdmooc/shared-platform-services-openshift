#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

SPECIALIST_DIR="${KEYCLOAK_SPECIALIST_DIR:-../keycloak-enterprise-roadmap-v7}"

if ! oc api-resources --api-group=config.openshift.io --no-headers 2>/dev/null | grep -qE '^clusterversions[[:space:]]'; then
  echo "ERROR: current context is not OpenShift/CRC" >&2
  exit 2
fi

echo "== CRC preflight"
oc get clusterversion version
oc get nodes -o wide
echo "== Current node allocation"
oc describe node crc | sed -n '/Allocated resources:/,/Events:/p' || true

oc -n shared-observability wait --for=condition=Available deploy/otel-collector --timeout=60s

DEPLOY_SCRIPT="${SPECIALIST_DIR}/install/01-crc-local/scripts/deploy-keycloak-crc.sh"
if [[ ! -f "${DEPLOY_SCRIPT}" ]]; then
  echo "ERROR: Keycloak specialist repository not found at ${SPECIALIST_DIR}" >&2
  echo "Clone it beside this repository or set KEYCLOAK_SPECIALIST_DIR." >&2
  exit 1
fi

export KC_DB_USERNAME="${KC_DB_USERNAME:-keycloak}"
if [[ -z "${KC_DB_PASSWORD:-}" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    export KC_DB_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
  else
    export KC_DB_PASSWORD="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
  fi
  GENERATED_DB_CREDENTIAL=true
else
  GENERATED_DB_CREDENTIAL=false
fi

bash "${DEPLOY_SCRIPT}"
bash scripts/bootstrap-shared-identity-crc.sh

oc -n keycloak-system get keycloak keycloak
oc -n keycloak-system get pods,svc,route,ingress 2>/dev/null || true
curl -kfsS https://keycloak.apps-crc.testing/realms/mayabank/.well-known/openid-configuration >/dev/null

unset KC_DB_PASSWORD
echo "SHARED_IDENTITY_CRC_DEPLOY=PASS"
echo "SHARED_OIDC_ISSUER=https://keycloak.apps-crc.testing/realms/mayabank"
echo "generated_db_credential=${GENERATED_DB_CREDENTIAL}"
