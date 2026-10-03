#!/usr/bin/env python3
"""Prepare D-090 TradeOps/ODM workload clients in the already-proven shared realm.

This is an idempotent CRC lab helper. It never prints client secrets.
Set SYNC_TARGET_SECRETS=true only when the target namespaces already exist.
"""

from __future__ import annotations

import base64
import json
import os
import ssl
import subprocess
import urllib.error
import urllib.parse
import urllib.request


KEYCLOAK_NAMESPACE = os.getenv("KEYCLOAK_NAMESPACE", "keycloak-system")
KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "https://keycloak.apps-crc.testing").rstrip("/")
REALM = os.getenv("SHARED_REALM", "mayabank")
ADMIN_SECRET_NAME = os.getenv("KEYCLOAK_ADMIN_SECRET", "keycloak-initial-admin")
SYNC_TARGET_SECRETS = os.getenv("SYNC_TARGET_SECRETS", "false").lower() == "true"
TRADEOPS_NAMESPACE = os.getenv("TRADEOPS_NAMESPACE", "tradeops")
ODM_NAMESPACE = os.getenv("ODM_NAMESPACE", "mayainsurance-decision-local")

SSL_CONTEXT = ssl._create_unverified_context()


def run_oc(*args: str, input_text: str | None = None) -> str:
    completed = subprocess.run(
        ["oc", *args],
        input=input_text,
        text=True,
        check=True,
        capture_output=True,
    )
    return completed.stdout.strip()


def secret_value(namespace: str, name: str, key: str) -> str:
    encoded = run_oc(
        "-n",
        namespace,
        "get",
        "secret",
        name,
        "-o",
        f"jsonpath={{.data.{key}}}",
    )
    return base64.b64decode(encoded).decode("utf-8")


def request(
    path: str,
    *,
    method: str = "GET",
    token: str | None = None,
    json_body: dict | None = None,
    form: dict[str, str] | None = None,
) -> tuple[int, object]:
    headers: dict[str, str] = {}
    data = None
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if json_body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(json_body).encode("utf-8")
    elif form is not None:
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        data = urllib.parse.urlencode(form).encode("utf-8")
    req = urllib.request.Request(
        KEYCLOAK_URL + path,
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, context=SSL_CONTEXT, timeout=20) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read()
        body = json.loads(raw) if raw else {}
        return exc.code, body


def admin_token() -> str:
    username = secret_value(KEYCLOAK_NAMESPACE, ADMIN_SECRET_NAME, "username")
    admin_credential = secret_value(KEYCLOAK_NAMESPACE, ADMIN_SECRET_NAME, "password")
    status, body = request(
        "/realms/master/protocol/openid-connect/token",
        method="POST",
        form={
            "client_id": "admin-cli",
            "grant_type": "password",
            "username": username,
            "password": admin_credential,
        },
    )
    if status != 200 or not isinstance(body, dict) or not body.get("access_token"):
        raise RuntimeError(f"admin token failed: HTTP {status}")
    return str(body["access_token"])


def admin_get(path: str, token: str):
    status, body = request(path, token=token)
    if status != 200:
        raise RuntimeError(f"GET {path} failed: HTTP {status}")
    return body


def admin_post(path: str, token: str, payload: dict) -> None:
    status, body = request(path, method="POST", token=token, json_body=payload)
    if status != 201:
        raise RuntimeError(f"POST {path} failed: HTTP {status} {body}")


def ensure_scope(token: str, scope: str) -> str:
    scopes = admin_get(f"/admin/realms/{REALM}/client-scopes", token)
    for item in scopes:
        if item.get("name") == scope:
            return str(item["id"])
    admin_post(
        f"/admin/realms/{REALM}/client-scopes",
        token,
        {
            "name": scope,
            "protocol": "openid-connect",
            "attributes": {"include.in.token.scope": "true"},
        },
    )
    return ensure_scope(token, scope)


def ensure_client(token: str, client_id: str, payload: dict) -> str:
    clients = admin_get(
        f"/admin/realms/{REALM}/clients?clientId={urllib.parse.quote(client_id)}",
        token,
    )
    if clients:
        return str(clients[0]["id"])
    admin_post(f"/admin/realms/{REALM}/clients", token, payload)
    return ensure_client(token, client_id, payload)


def ensure_default_scope(token: str, client_uuid: str, scope_id: str) -> None:
    status, _ = request(
        f"/admin/realms/{REALM}/clients/{client_uuid}/default-client-scopes/{scope_id}",
        method="PUT",
        token=token,
    )
    if status != 204:
        raise RuntimeError(f"default scope link failed: HTTP {status}")


def ensure_audience_mapper(
    token: str, client_uuid: str, *, name: str, audience: str
) -> None:
    mappers = admin_get(
        f"/admin/realms/{REALM}/clients/{client_uuid}/protocol-mappers/models",
        token,
    )
    if any(item.get("name") == name for item in mappers):
        return
    admin_post(
        f"/admin/realms/{REALM}/clients/{client_uuid}/protocol-mappers/models",
        token,
        {
            "name": name,
            "protocol": "openid-connect",
            "protocolMapper": "oidc-audience-mapper",
            "config": {
                "included.client.audience": audience,
                "access.token.claim": "true",
            },
        },
    )


def current_client_secret(token: str, client_uuid: str) -> str:
    body = admin_get(
        f"/admin/realms/{REALM}/clients/{client_uuid}/client-secret",
        token,
    )
    value = str(body.get("value", ""))
    if not value:
        raise RuntimeError("client secret lookup returned empty value")
    return value


def sync_target_secret(
    token: str,
    client_uuid: str,
    namespace: str,
    target_secret: str,
) -> None:
    if not SYNC_TARGET_SECRETS:
        return
    run_oc("get", "namespace", namespace)
    value = current_client_secret(token, client_uuid)
    manifest = run_oc(
        "-n",
        namespace,
        "create",
        "secret",
        "generic",
        target_secret,
        f"--from-literal=client-secret={value}",
        "--dry-run=client",
        "-o",
        "yaml",
    )
    run_oc("apply", "-f", "-", input_text=manifest)


def main() -> int:
    run_oc("api-resources", "--api-group=config.openshift.io")
    token = admin_token()

    ensure_client(
        token,
        "ai-gateway",
        {
            "clientId": "ai-gateway",
            "enabled": True,
            "protocol": "openid-connect",
            "publicClient": True,
            "standardFlowEnabled": False,
            "directAccessGrantsEnabled": False,
            "serviceAccountsEnabled": False,
        },
    )
    scope_id = ensure_scope(token, "ai.inference")

    client_payload = lambda client_id: {
        "clientId": client_id,
        "enabled": True,
        "protocol": "openid-connect",
        "publicClient": False,
        "serviceAccountsEnabled": True,
        "fullScopeAllowed": False,
        "standardFlowEnabled": False,
        "directAccessGrantsEnabled": False,
    }

    tradeops_uuid = ensure_client(token, "tradeops-ai", client_payload("tradeops-ai"))
    odm_uuid = ensure_client(token, "odm-ai", client_payload("odm-ai"))

    for client_uuid, client_id in (
        (tradeops_uuid, "tradeops-ai"),
        (odm_uuid, "odm-ai"),
    ):
        ensure_default_scope(token, client_uuid, scope_id)
        ensure_audience_mapper(
            token,
            client_uuid,
            name=f"{client_id}-ai-gateway-audience",
            audience="ai-gateway",
        )

    sync_target_secret(
        token, tradeops_uuid, TRADEOPS_NAMESPACE, "tradeops-ai-client-secret"
    )
    sync_target_secret(token, odm_uuid, ODM_NAMESPACE, "odm-ai-client-secret")

    print("D090_AI_GATEWAY_AUDIENCE=PASS")
    print("D090_AI_INFERENCE_SCOPE=PASS")
    print("D090_TRADEOPS_CLIENT=PASS")
    print("D090_ODM_CLIENT=PASS")
    print(
        "D090_TARGET_SECRETS_SYNC="
        + ("PASS" if SYNC_TARGET_SECRETS else "SKIPPED")
    )
    print(
        "claim=identity contract prepared; observed token evidence requires "
        "d090_test_ai_identities_crc.py"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
