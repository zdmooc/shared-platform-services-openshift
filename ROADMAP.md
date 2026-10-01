# Roadmap — S0→S8 + O3 Evidence Hardening

| Iteration | Scope | Repository status | Runtime claim |
|---|---|---|---|
| S0 | Foundation & governance | IMPLEMENTED | NOT_APPLICABLE |
| S1 | GitOps / Argo CD contracts | IMPLEMENTED | CRC_PENDING |
| S2 | Observability shared contracts | IMPLEMENTED | S5_GATE |
| S3 | IAM / secrets shared contracts | IMPLEMENTED | CRC_PENDING |
| S4 | Quality / CI / SonarQube contracts | IMPLEMENTED | S6_PROVEN |
| S5 | Ephemeral runtime portability | IMPLEMENTED | REPAIR_AND_REEXECUTE |
| S6 | Keycloak + SonarQube live smoke | IMPLEMENTED | **CI_RUNTIME_PROVEN_CONTAINER_SMOKE** |
| S7 | Instant Payments consumer onboarding | IMPLEMENTED | STATIC_VERIFY / CRC_PENDING |
| S8 | Hardening / rollback / evidence | IMPLEMENTED | NOT_APPLICABLE |

## O3 evidence-hardening sequence

1. synchronize evidence truth;
2. repair S5 Kind runner installation;
3. strengthen S5 from endpoint reachability to OTLP consumer → Collector → Prometheus path;
4. harden static validation;
5. verify first-consumer integration;
6. add CRC/OpenShift execution gate without making a false hosted-CI claim;
7. close O3 with updated evidence.

## V1 truth boundary

Repository-complete means the architecture, contracts and implementation assets exist.

Runtime-proven means the corresponding execution has actually succeeded.

CRC/OpenShift, HA and production remain independent proof gates.
