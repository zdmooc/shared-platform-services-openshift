#!/usr/bin/env bash
set -euo pipefail

python scripts/validate_yaml.py
python scripts/validate_kustomize_refs.py
python scripts/validate-security-hygiene.py

required=(
  README.md
  ROADMAP.md
  config/dependency-classification.yaml
  gitops/base/appproject.yaml
  platform/observability/otel/kustomization.yaml
  docs/contracts/IAM_CONTRACT.md
  docs/contracts/QUALITY_GATE_CONTRACT.md
  platform/runtime-ci/kustomization.yaml
  consumers/instant-payments/CONTRACT.md
  docs/runbooks/HARDENING_ROLLBACK.md
  docs/operations/FAILURE_MODE_MATRIX.md
  evidence/CLAIM-EVIDENCE-MATRIX.md
  docs/iterations/S5-S8-COMPLETION.md
)

for file in "${required[@]}"; do
  test -f "$file" || { echo "Missing required file: $file"; exit 1; }
done

grep -q "apache-camel" config/dependency-classification.yaml
grep -q "product-mongodb-read-model" config/dependency-classification.yaml
grep -q "mayabank-instant-payments-resilience-platform" consumers/instant-payments/CONTRACT.md
grep -q "CI_RUNTIME_PROVEN_CONTAINER_SMOKE" evidence/CLAIM-EVIDENCE-MATRIX.md
grep -q "CRC/OpenShift" docs/iterations/S5-S8-COMPLETION.md

echo "SHARED_PLATFORM_STRUCTURAL_VALIDATION=PASS"
