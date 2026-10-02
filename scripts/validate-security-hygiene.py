#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
ACTIVE = [
    ROOT / "config",
    ROOT / "consumers",
    ROOT / "docs",
    ROOT / "gitops",
    ROOT / "platform",
    ROOT / "quality",
    ROOT / "scripts",
    ROOT / ".github" / "workflows",
]

errors: list[str] = []
jwt_re = re.compile(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")
credential_re = re.compile(
    r"(?i)(password|secret|token)\s*[:=]\s*['\"]?([^\s'\"]{20,})"
)

for root in ACTIVE:
    if not root.exists():
        continue
    paths = [root] if root.is_file() else root.rglob("*")
    for path in paths:
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".md", ".yaml", ".yml", ".json", ".py", ".sh", ".properties"}:
            continue
        rel = path.relative_to(ROOT)
        if rel == pathlib.Path("scripts/validate-security-hygiene.py"):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")

        if "-----BEGIN PRIVATE KEY-----" in text or "-----BEGIN RSA PRIVATE KEY-----" in text:
            errors.append(f"{rel}: private key material found")

        if jwt_re.search(text):
            errors.append(f"{rel}: JWT-like token found")

        for match in credential_re.finditer(text):
            value = match.group(2).strip().rstrip(",}])")
            if value.startswith(("REPLACE_", "EXAMPLE_", "ci-only-password")):
                continue
            if value.startswith(("$(", "${", "$")):
                continue
            errors.append(f"{rel}: possible long-lived secret literal")
            break

if errors:
    print("SECURITY_HYGIENE=FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("SECURITY_HYGIENE=PASS")
