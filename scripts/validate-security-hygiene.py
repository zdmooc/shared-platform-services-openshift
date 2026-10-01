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

for root in ACTIVE:
    if not root.exists():
        continue
    paths = [root] if root.is_file() else root.rglob("*")
    for path in paths:
        if not path.is_file():
            continue
        if path.suffix.lower() not in {".md", ".yaml", ".yml", ".json", ".py", ".sh", ".properties"}:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = path.relative_to(ROOT)

        if "-----BEGIN PRIVATE KEY-----" in text or "-----BEGIN RSA PRIVATE KEY-----" in text:
            errors.append(f"{rel}: private key material found")

        if jwt_re.search(text):
            errors.append(f"{rel}: JWT-like token found")

        if re.search(r"(?i)(password|secret|token)\s*[:=]\s*['\"]?(?!REPLACE_|EXAMPLE_|ci-only-password)[A-Za-z0-9+/=_-]{20,}", text):
            errors.append(f"{rel}: possible long-lived secret literal")

if errors:
    print("SECURITY_HYGIENE=FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("SECURITY_HYGIENE=PASS")
