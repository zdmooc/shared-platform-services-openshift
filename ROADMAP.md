# Roadmap — S0→S8

| Iteration | Scope | Repository status | Runtime claim |
|---|---|---|---|
| S0 | Foundation & governance | IMPLEMENTED | NOT_APPLICABLE |
| S1 | GitOps / Argo CD contracts | IMPLEMENTED | CRC_PENDING |
| S2 | Observability shared contracts | IMPLEMENTED | CRC_PENDING |
| S3 | IAM / secrets shared contracts | IMPLEMENTED | CRC_PENDING |
| S4 | Quality / CI / SonarQube contracts | IMPLEMENTED | CRC_PENDING |
| S5 | Ephemeral runtime portability | IMPLEMENTED / WORKFLOW_DEFINED | CI_RESULT_PENDING |
| S6 | Keycloak + SonarQube live smoke | IMPLEMENTED / WORKFLOW_DEFINED | CI_RESULT_PENDING |
| S7 | Instant Payments consumer onboarding | IMPLEMENTED | CRC_SHARED_CONSUMPTION_PENDING |
| S8 | Hardening / rollback / evidence | IMPLEMENTED | NOT_APPLICABLE |

## S0 — Foundation

Architecture, namespace baseline, dependency classification, ADR ownership model and bootstrap runbook.

## S1 — GitOps

AppProject, consumer Application/ApplicationSet contracts, sync policy and namespace boundaries.

## S2 — Observability

OpenTelemetry Collector, Prometheus ServiceMonitor contract, Grafana asset and consumer telemetry contract.

## S3 — IAM & secrets

OIDC contract, Keycloak realm/client conventions, External Secrets/Vault-compatible pattern, RBAC and NetworkPolicy baseline.

## S4 — Quality

SonarQube contract, repository validation and reusable quality workflow.

## S5 — Runtime portability

Kind smoke workflow deploys the Kubernetes-native V1 core and validates the OTel service from inside the cluster. Successful CI may claim Kind single-node portability only.

## S6 — Identity & quality runtime smoke

Dedicated workflow starts Keycloak and SonarQube and validates OIDC discovery and SonarQube system readiness. Enterprise persistence, HA and federation remain out of scope.

## S7 — First consumer

`mayabank-instant-payments-resilience-platform` has a non-destructive `shared-platform` overlay. Shared OTel is consumed; Kafka and PostgreSQL remain dedicated for payment resilience tests.

## S8 — Hardening

Failure modes, rollback, claim/evidence boundaries and V1 completion are documented.

## V1 exit criteria

V1 is repository-complete when:
- S0→S8 assets exist and structural CI validates them;
- runtime workflows exist for Kubernetes portability, IAM and quality;
- at least one product has a concrete shared-platform integration profile;
- no CRC or production runtime claim is made without evidence.

CRC evidence is a separate execution gate, not a prerequisite for repository V1 completeness.
