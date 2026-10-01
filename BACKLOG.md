# Backlog

## Closed — V1 / O3

- [x] repository bootstrap and ownership model;
- [x] namespace and platform labels;
- [x] Argo CD project / ApplicationSet contracts;
- [x] shared telemetry contracts;
- [x] Keycloak/OIDC and secret-consumption patterns;
- [x] SonarQube/quality-gate integration contract;
- [x] reusable CI and repository validation;
- [x] evidence model;
- [x] S5 Kind runtime smoke;
- [x] S5 consumer → OTLP → Collector → Prometheus proof;
- [x] S6 Keycloak OIDC + SonarQube container smoke;
- [x] S7 Instant Payments shared-platform contract verification;
- [x] hardened OTel Collector pod security;
- [x] CRC/OpenShift execution script and evidence runbook.

## Next proof gate

- [ ] execute docs/runbooks/CRC_RUNTIME_VALIDATION.md on the user's real CRC/OpenShift Local environment;
- [ ] archive sanitized CRC evidence;
- [ ] promote only the exact successful capability to CRC_RUNTIME_PROVEN.

## Intentionally deferred / mission-driven

- shared Kafka/Redpanda runtime;
- shared PostgreSQL runtime;
- shared MinIO/S3 runtime;
- production-grade Vault/CyberArk deployment;
- HA/multi-node shared-platform proofs;
- enterprise PKI integration;
- live OpenShift GitOps/Keycloak/SonarQube Operator installation;
- production readiness.

These capabilities are implemented only when a current mission or measurable duplication justifies them.
