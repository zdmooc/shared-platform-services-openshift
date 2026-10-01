from pathlib import Path
import json
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
errors = []

for path in ROOT.rglob("*"):
    if any(part in {".git", ".venv"} for part in path.parts):
        continue
    try:
        if path.suffix in {".yaml", ".yml"}:
            with path.open("r", encoding="utf-8") as f:
                list(yaml.safe_load_all(f))
        elif path.suffix == ".json":
            with path.open("r", encoding="utf-8") as f:
                json.load(f)
    except Exception as exc:
        errors.append(f"{path.relative_to(ROOT)}: {exc}")

if errors:
    print("\n".join(errors))
    sys.exit(1)

print("YAML/JSON syntax: PASS")
