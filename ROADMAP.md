# Roadmap — S0→S4

| Iteration | Scope | Repository status | Runtime claim |
|---|---|---|---|
| S0 | Foundation & governance | IMPLEMENTED | NOT_APPLICABLE |
| S1 | GitOps / Argo CD contracts | IMPLEMENTED | TO_BE_PROVEN |
| S2 | Observability shared contracts | IMPLEMENTED | TO_BE_PROVEN |
| S3 | IAM / secrets shared contracts | IMPLEMENTED | TO_BE_PROVEN |
| S4 | Quality / CI / SonarQube contracts | IMPLEMENTED | TO_BE_PROVEN |

## S0 — Foundation

Deliverables: architecture, namespace baseline, dependency classification, ADR ownership model, bootstrap runbook.

## S1 — GitOps

Deliverables: AppProject, consumer ApplicationSet contract, sync policy, namespace boundaries and GitOps runbook.

## S2 — Observability

Deliverables: OpenTelemetry Collector baseline, ServiceMonitor-compatible pattern, Grafana dashboard provisioning contract, labels and telemetry contract.

## S3 — IAM & secrets

Deliverables: OIDC contract, Keycloak realm/client conventions, External Secrets/Vault-compatible contract, RBAC and NetworkPolicy baseline.

## S4 — Quality & CI

Deliverables: repository validation workflow, reusable quality workflow, SonarQube contract, YAML/Kustomize validation, dependency ownership checks and evidence structure.

## Exit criteria

The repository is structurally complete when all S0→S4 files are present and CI validates their syntax/consistency. Deployment evidence remains separate and cannot be inferred from repository completeness.
