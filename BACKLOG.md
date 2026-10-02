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
- [x] Instant Payments shared-platform contract verification;
- [x] API Management shared-platform consumer contract verification;
- [x] API Management classified as SPECIALIZED_PLATFORM consuming L2 services;
- [x] hardened OTel Collector pod security;
- [x] CRC/OpenShift shared-observability execution script and evidence runbook;
- [x] local CRC evidence capture wrapper with raw evidence ignored by Git.

## Next proof gate

- [x] execute docs/runbooks/CRC_RUNTIME_VALIDATION.md on the user's real CRC/OpenShift Local environment;
- [x] record sanitized CRC shared-observability evidence;
- [x] promote shared observability to CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY;
- [ ] onboard API Management runtime to shared OIDC and shared OTel on CRC.

## API Management next consumer promotion

After the platform CRC observability gate:

- [ ] keep existing Docker CI runtime as DEDICATED_FOR_TEST;
- [ ] add a separate shared-platform target profile in mayabank-api-management-architecture;
- [ ] consume shared OIDC configuration rather than deploying a second target Keycloak;
- [ ] export gateway/API telemetry to shared OTel;
- [ ] prove the consumer path on CRC;
- [ ] promote only the capabilities actually observed.

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
