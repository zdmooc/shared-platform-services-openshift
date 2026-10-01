#!/usr/bin/env bash
set -euo pipefail

KEYCLOAK_IMAGE="${KEYCLOAK_IMAGE:-quay.io/keycloak/keycloak:26.0.7}"
SONAR_IMAGE="${SONAR_IMAGE:-sonarqube:10.7-community}"

cleanup() {
  docker rm -f shared-keycloak shared-sonarqube >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

docker run -d --name shared-keycloak   -p 18080:8080   -e KC_BOOTSTRAP_ADMIN_USERNAME=admin   -e KC_BOOTSTRAP_ADMIN_PASSWORD=ci-only-password   "$KEYCLOAK_IMAGE" start-dev >/dev/null

for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:18080/realms/master/.well-known/openid-configuration >/tmp/keycloak-oidc.json 2>/dev/null; then
    break
  fi
  sleep 2
done

grep -q '"issuer"' /tmp/keycloak-oidc.json

docker run -d --name shared-sonarqube   -p 19000:9000   -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true   "$SONAR_IMAGE" >/dev/null

for i in $(seq 1 90); do
  status="$(curl -fsS http://127.0.0.1:19000/api/system/status 2>/dev/null || true)"
  if echo "$status" | grep -Eq '"status":"(UP|GREEN)"'; then
    echo "$status" >/tmp/sonarqube-status.json
    break
  fi
  sleep 2
done

test -s /tmp/sonarqube-status.json

echo "S6_KEYCLOAK_OIDC_SMOKE=PASS"
echo "S6_SONARQUBE_SMOKE=PASS"
echo "claim=CI_RUNTIME_PROVEN_CONTAINER_SMOKE"
echo "crc_claim=NOT_PROVEN"
