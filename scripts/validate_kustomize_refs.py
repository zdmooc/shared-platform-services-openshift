from pathlib import Path
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
errors = []

for k in ROOT.rglob("kustomization.yaml"):
    data = yaml.safe_load(k.read_text(encoding="utf-8")) or {}
    for resource in data.get("resources", []):
        if str(resource).startswith(("http://", "https://")):
            continue
        target = (k.parent / resource).resolve()
        if not target.exists():
            errors.append(f"{k.relative_to(ROOT)} -> missing resource {resource}")

if errors:
    print("\n".join(errors))
    sys.exit(1)

print("Kustomize local references: PASS")
