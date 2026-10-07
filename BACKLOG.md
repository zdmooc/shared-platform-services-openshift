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
- [x] execute the Shared Identity CRC gate through the RHBK specialist runtime + shared realm bootstrap;
- [x] promote observed Keycloak/OIDC behavior to `CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN`;
- [x] onboard API Management runtime to shared OIDC and shared OTel on CRC;
- [x] onboard Instant Payments runtime to shared OIDC and shared OTel on CRC and promote it to `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`.

## API Management next consumer promotion

After the platform CRC observability gate:

- [x] keep existing Docker CI runtime as DEDICATED_FOR_TEST;
- [x] add a separate shared-platform target profile in mayabank-api-management-architecture;
- [x] consume shared OIDC configuration rather than deploying a second target Keycloak;
- [x] export gateway/API telemetry to shared OTel;
- [x] prove the consumer path on CRC;
- [x] promote only the capabilities actually observed.

## Intentionally deferred / mission-driven

- shared Kafka/Redpanda runtime;
- shared PostgreSQL runtime;
- shared MinIO/S3 runtime;
- production-grade Vault/CyberArk deployment;
- HA/multi-node shared-platform proofs;
- enterprise PKI integration;
- fresh OpenShift GitOps reconciliation proof;
- SonarQube runtime/operator proof on CRC;
- further Keycloak operations evidence beyond the proven shared realm/OIDC bootstrap (restart persistence, upgrade, HA as applicable);
- production readiness.

These capabilities are implemented only when a current mission or measurable duplication justifies them.


## Customer/KYC consumer onboarding

- [x] reuse the existing Customer/KYC architecture repository;
- [x] add an explicit `CapabilityConsumption` contract;
- [x] add a deployable Kustomize consumer surface;
- [x] wire shared OIDC and shared OTel endpoints;
- [x] add an opt-in egress NetworkPolicy;
- [x] add repository CI validation;
- [x] add the Shared Platform side consumer contract;
- [x] add an Argo CD AppProject and Application contract;
- [x] keep runtime status at `STATIC_CONSUMER_CONTRACT_VERIFIED` until observed.

## Current closure

The planned Shared Platform + API Management + first product-consumer onboarding scope is **COMPLETE**. Instant Payments is also runtime-proven as a Shared Platform consumer on the tested single-node CRC as of 2026-10-03.

Further runtime gates are mission-driven, not required to close this iteration set.


## D-093 Platform Operator

### Closed — K2 / K3 I2-I4
- [x] accept CapabilityConsumption as canonical Kubernetes Platform API;
- [x] implement Go/Kubebuilder/controller-runtime API and controller;
- [x] validate schema, go vet, unit/envtest on Kubernetes 1.35;
- [x] prove Manage baseline creation on Kind;
- [x] prove Server-Side Apply field manager;
- [x] prove declared profile update;
- [x] prove managed-resource drift recovery;
- [x] prove controller restart recovery;
- [x] prove brownfield Observe + OwnershipConflict with no mutation;
- [x] prove explicit brownfield adoption after product baseline removal;
- [x] prove deletionPolicy=Retain;
- [x] record canonical Kind runtime evidence.

Allowed claim: `KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR`.

### Closed — K3/K4 I5 CRC consumer #1
- [x] deploy the Operator on the user's CRC/OpenShift Local;
- [x] validate OpenShift/SCC-specific compatibility with `restricted-v2`;
- [x] prove brownfield Observe + OwnershipConflict with zero mutation;
- [x] introduce the measured `payments-medium` quota profile before Manage;
- [x] onboard Instant Payments as consumer #1 through `CapabilityConsumption`;
- [x] execute explicit Observe -> Manage adoption;
- [x] establish `platform-default-deny` before removing legacy `default-deny`;
- [x] prove zero double ownership after handoff;
- [x] keep Argo CD as product workload reconciler and restore `Synced/Healthy`;
- [x] revalidate Shared OIDC and real Shared OTel trace export;
- [x] revalidate the payment runtime with `FINAL_DEMO_RESULT=PASS`;
- [x] capture sanitized CRC evidence before promotion.

Allowed claim: `CONSUMER_1_CRC_RUNTIME_PROVEN`.

Canonical evidence: `evidence/runtime/D093-K3-I5-crc-consumer1-instant-payments-20261005.md`.

### I6A — Production-style Operator Engineering — CLOSED / RUNTIME_PROVEN_WITHIN_KIND_SCOPE
- [x] add Kubebuilder-style Makefile and pinned controller-gen tooling;
- [x] add CRD profile validation markers;
- [x] add Progressing / Degraded conditions;
- [x] add bounded reconciliation metrics;
- [x] add Lease-based leader election + RBAC;
- [x] add partial-apply failure / idempotent recovery envtest;
- [x] extend Kind runtime script with CRD negative test, two-replica Lease proof and metrics proof;
- [x] Platform CI green on the I6A branch — run `37587208717` SUCCESS;
- [x] D093 Kind runtime workflow green with I6A evidence — run `37587208723` SUCCESS;
- [ ] merge I6A and promote the claim.

No destructive finalizer is introduced: `deletionPolicy=Retain` remains the V1 brownfield safety contract.

### I6B — Day-2 / Failure Engineering — NEXT
- [ ] preserve the root reconcile error after writing `Degraded=True` so controller-runtime retry/backoff is triggered;
- [ ] prove automatic recovery after transient apply failure, not only a manually invoked second reconcile;
- [ ] surface dependency/read failures without masking the root cause;
- [ ] prove controller restart + leader failover + reconciliation continuity;
- [ ] prove deleted managed-resource reconstruction under a transient failure;
- [ ] record bounded retry/failure metrics and evidence.

### Next — I6 CRC consumer #2 / TradeOps brownfield
- [ ] onboard TradeOps in Observe;
- [ ] inventory real brownfield ownership conflicts;
- [ ] preserve product-owned workloads, PostgreSQL, Redpanda/Kafka and Qdrant;
- [ ] transfer only the common platform baseline after explicit approval;
- [ ] prove no double ownership and no runtime regression;
- [ ] promote only observed CRC evidence.
