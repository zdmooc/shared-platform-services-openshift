#!/usr/bin/env python3
"""Observed CRC probe for D-090 distinct workload identities."""

from __future__ import annotations

import base64
import json
import os
import ssl
import subprocess
import urllib.parse
import urllib.request


KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "https://keycloak.apps-crc.testing").rstrip("/")
REALM = os.getenv("SHARED_REALM", "mayabank")
TRADEOPS_NAMESPACE = os.getenv("TRADEOPS_NAMESPACE", "tradeops")
ODM_NAMESPACE = os.getenv("ODM_NAMESPACE", "mayainsurance-decision-local")
SSL_CONTEXT = ssl._create_unverified_context()


def run_oc(*args: str) -> str:
    return subprocess.run(
        ["oc", *args], text=True, check=True, capture_output=True
    ).stdout.strip()


def secret(namespace: str, name: str) -> str:
    encoded = run_oc(
        "-n", namespace, "get", "secret", name,
        "-o", "jsonpath={.data.client-secret}"
    )
    return base64.b64decode(encoded).decode("utf-8")


def token_for(client_id: str, client_secret: str) -> str:
    data = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "client_secret": client_secret,
            "grant_type": "client_credentials",
        }
    ).encode("utf-8")
    req = urllib.request.Request(
        f"{KEYCLOAK_URL}/realms/{REALM}/protocol/openid-connect/token",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    with urllib.request.urlopen(req, context=SSL_CONTEXT, timeout=20) as response:
        body = json.loads(response.read().decode("utf-8"))
    value = str(body.get("access_token", ""))
    if not value:
        raise RuntimeError(f"no access token for {client_id}")
    return value


def claims(token: str) -> dict:
    part = token.split(".")[1]
    part += "=" * (-len(part) % 4)
    return json.loads(base64.urlsafe_b64decode(part))


def verify(client_id: str, namespace: str, secret_name: str) -> None:
    payload = claims(token_for(client_id, secret(namespace, secret_name)))
    if payload.get("iss") != f"{KEYCLOAK_URL}/realms/{REALM}":
        raise RuntimeError(f"{client_id}: issuer mismatch")
    audience = payload.get("aud")
    audiences = audience if isinstance(audience, list) else [audience]
    if "ai-gateway" not in audiences:
        raise RuntimeError(f"{client_id}: missing ai-gateway audience")
    if "ai.inference" not in set(str(payload.get("scope", "")).split()):
        raise RuntimeError(f"{client_id}: missing ai.inference scope")
    if payload.get("azp") != client_id:
        raise RuntimeError(f"{client_id}: azp mismatch")


def main() -> int:
    verify("tradeops-ai", TRADEOPS_NAMESPACE, "tradeops-ai-client-secret")
    print("D090_TRADEOPS_TOKEN=PASS")
    verify("odm-ai", ODM_NAMESPACE, "odm-ai-client-secret")
    print("D090_ODM_TOKEN=PASS")
    print("D090_DISTINCT_WORKLOAD_IDENTITIES=PASS")
    print(
        "claim=identity portion of G2/G4 observed only when this output is "
        "executed on CRC and retained as evidence"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
