#!/usr/bin/env bash
set -euo pipefail

python scripts/validate_yaml.py
python scripts/validate_kustomize_refs.py

required=(
  README.md
  ROADMAP.md
  config/dependency-classification.yaml
  gitops/base/appproject.yaml
  platform/observability/otel/kustomization.yaml
  docs/contracts/IAM_CONTRACT.md
  docs/contracts/QUALITY_GATE_CONTRACT.md
)

for file in "${required[@]}"; do
  test -f "$file" || { echo "Missing required file: $file"; exit 1; }
done

grep -q "apache-camel" config/dependency-classification.yaml
grep -q "product-mongodb-read-model" config/dependency-classification.yaml

echo "Shared platform structural validation: PASS"
