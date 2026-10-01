# Claim / Evidence Matrix

**Date:** 2026-10-01

| Capability | Repository | Static/CI | CRC/OpenShift | Production |
|---|---|---|---|---|
| Foundation/governance | IMPLEMENTED | Platform CI PASS | N/A | NOT_CLAIMED |
| Argo CD contracts | IMPLEMENTED | RENDERABLE | PENDING | NOT_CLAIMED |
| OpenTelemetry Collector | IMPLEMENTED | S5 repair in progress | PENDING | NOT_CLAIMED |
| Prometheus integration contract | IMPLEMENTED | RENDERABLE | PENDING | NOT_CLAIMED |
| Grafana asset | IMPLEMENTED | STATIC | PENDING | NOT_CLAIMED |
| Keycloak/OIDC | IMPLEMENTED_CONTRACT | **S6 CI_RUNTIME_PROVEN_CONTAINER_SMOKE** | PENDING | NOT_CLAIMED |
| SonarQube | IMPLEMENTED_CONTRACT | **S6 CI_RUNTIME_PROVEN_CONTAINER_SMOKE** | PENDING | NOT_CLAIMED |
| Instant Payments consumer overlay | IMPLEMENTED | consumer render evidence to verify | PENDING | NOT_CLAIMED |
| Shared Kafka | DEFERRED | N/A | NOT_DEPLOYED | NOT_CLAIMED |
| Shared PostgreSQL | DEFERRED | N/A | NOT_DEPLOYED | NOT_CLAIMED |
| Shared MinIO | DEFERRED | N/A | NOT_DEPLOYED | NOT_CLAIMED |

## Recorded workflow evidence

- Platform CI run `36841017401`: **SUCCESS**.
- S6 Identity Quality Smoke run `36840813149`: **SUCCESS**.
- S5 Runtime Smoke run `36840802013`: **FAILED BEFORE CLUSTER EXECUTION** because Kind installation attempted to modify `/usr/local/bin`.

## Rule

A workflow definition is not evidence by itself.

A claim is promoted only after a successful observed run and an evidence record is updated.

CRC/OpenShift and production columns remain unchanged until those environments are actually executed.
