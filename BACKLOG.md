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
- [x] I6A merged to `main` via PR #8 — squash commit `0d1d50ff52cfe1ee1734361db89837f34baec744`.

No destructive finalizer is introduced: `deletionPolicy=Retain` remains the V1 brownfield safety contract.

### I6B — Day-2 / Failure Engineering — CLOSED / KIND_RUNTIME_PROVEN_WITHIN_SCOPE
- [x] preserve the root reconcile error after writing `Degraded=True` so controller-runtime retry/backoff is triggered;
- [x] implement Kind proof for automatic recovery after transient RBAC/apply failure without CR mutation;
- [x] surface dependency/read failures without masking the root cause;
- [x] implement leader-loss / Lease failover / reconciliation-continuity Kind proof;
- [x] implement deleted managed-resource reconstruction after leader failover;
- [x] add bounded retryable-failure metric; Platform CI `37590043833` SUCCESS and Kind Runtime `37590044290` SUCCESS.
- [x] merged PR #9 to `main` — squash commit `079b3f11a4b514e636b04bcaf97feabbc3fc66f0`.

### I6C — OLM / OpenShift Operator Packaging — CLOSED / KIND_OLM_LIFECYCLE_PROVEN
- [x] bundle v0.1.0 lifecycle fixture;
- [x] current bundle v0.2.0 + CSV;
- [x] explicit `replaces: v0.1.0` upgrade edge;
- [x] stable file-based catalog;
- [x] bundle/catalog Dockerfiles;
- [x] OpenShift OLM Classic manifests;
- [x] OpenShift 4.22 OLM v1 ClusterCatalog/ClusterExtension surfaces;
- [x] CI bundle/FBC/image build gates;
- [x] Kind OLM install/upgrade/uninstall test implemented;
- [x] Platform CI `37599472773` SUCCESS;
- [x] Kind OLM lifecycle `37599472919` SUCCESS;
- [x] PR #10 merged to `main` — squash commit `0573eeab564a901f1a25f47467a8aca7d6b8ebea`; I6C CLOSED.

### D-093 DAAROPS technical closure

**D-093 CLOSED / CRC_SCOPE_RUNTIME_PROVEN (2026-10-09).** I6A/I6B/I6C and OP1–OP4 complete for the agreed CRC gate. OP3 proved real Argo CD self-heal + Operator SSA recovery; OP2 then proved CRC OLM bundle v0.1.0 install, v0.2.0 upgrade, quota reconstruction, uninstall/Retain and restoration of the original digest-pinned Operator. Separate `D093_POST_OLM_HANDOFF_CHECK=PASS`: direct Operator 1/1 and pinned, Instant Payments Ready/Reconciled, quota 20Gi, Argo Synced/Healthy, test resources absent. See `docs/iterations/D093-OP2-OPENSHIFT-OLM-LIFECYCLE.md`. Boundary: `CRC_SINGLE_NODE_NOT_PRODUCTION_HA`; OLM fixture does not prove functional binary upgrade. TradeOps consumer #2 remains Observe-only pending separate approval and is not covered by the D-093 closure.

### Next — I6 CRC consumer #2 / TradeOps brownfield
- [x] prepare TradeOps Observe CR and zero-mutation evidence wrapper;
- [x] execute TradeOps in Observe on CRC — `D093_TRADEOPS_OBSERVE_CRC_RUNTIME_PROVEN`;
- [x] inventory real brownfield ownership conflicts — `OwnershipConflict` observed; detailed message retained in local raw evidence;
- [ ] refresh brownfield capacity/resource profile before any Manage decision;
- [x] preserve product-owned workloads, PostgreSQL, Redpanda/Kafka and Qdrant during Observe — zero mutation proven;
- [ ] transfer only the common platform baseline after explicit approval;
- [ ] prove no double ownership and no runtime regression;
- [ ] promote only observed CRC evidence.

Current status: **OBSERVE_CRC_RUNTIME_PROVEN / OWNERSHIP_CONFLICT_OBSERVED / MANAGE_NOT_AUTHORIZED**. Canonical evidence: `evidence/runtime/D093-I6-crc-consumer2-tradeops-observe-20261007.md`.
