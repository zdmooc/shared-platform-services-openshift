# Roadmap — Shared Platform Services

## V1 / O3 status

| Iteration | Scope | Repository status | Evidence |
|---|---|---|---|
| S0 | Foundation & governance | IMPLEMENTED | STATIC_VALIDATED |
| S1 | GitOps / Argo CD contracts | IMPLEMENTED | STATIC_VALIDATED / CRC_PENDING |
| S2 | Observability shared contracts | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND + CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY |
| S3 | IAM / secrets contracts | IMPLEMENTED | CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN for shared realm/OIDC; secrets/PKI remain contract-level |
| S4 | Quality / SonarQube contracts | IMPLEMENTED | S6 PROVEN |
| S5 | Kind runtime portability | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND |
| S6 | Keycloak + SonarQube live smoke | IMPLEMENTED | CI_RUNTIME_PROVEN_CONTAINER_SMOKE |
| S7 | Instant Payments onboarding | IMPLEMENTED | CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER |
| S8 | Hardening / rollback / evidence | IMPLEMENTED | STATIC_VALIDATED |
| O3 | Evidence hardening | COMPLETE | differentiated CRC evidence recorded; HA/production not claimed |
| D-093 K3 I4 | CapabilityConsumption Platform Operator | IMPLEMENTED | ENVTEST_VALIDATED + KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR |
| D-093 K3/K4 I5 | Instant Payments consumer #1 on CRC | COMPLETE | CONSUMER_1_CRC_RUNTIME_PROVEN |
| D-093 I6A | Production-style Go/Kubebuilder hardening | CLOSED | PLATFORM_CI_PROVEN + KIND_RUNTIME_PROVEN_I6A |
| D-093 I6B | Day-2 / Failure Engineering | CLOSED | PLATFORM_CI_PROVEN + KIND_RUNTIME_PROVEN_I6B_DAY2 |
| D-093 I6C | OLM / OpenShift Operator packaging | CLOSED | KIND_OLM_LIFECYCLE_PROVEN + OPENSHIFT_OPERATOR_RUNTIME_PROVEN_CONSUMER_1 |
| D-093 OP1 | DAAROPS Operator interview hardening | CLOSED / CI VALIDATED | interview surface and safe preflight |
| D-093 OP2 | OpenShift CRC OLM lifecycle | CLOSED / CRC RUNTIME PROVEN | OP2_OPENSHIFT_OLM_LIFECYCLE_RESULT=PASS |
| D-093 OP3 | Operator/Argo Day-2 self-heal | CLOSED / CRC RUNTIME PROVEN | OP3_OPERATOR_ARGO_DAY2_INTEGRATED_DEMO_PROVEN=PASS |
| D-093 OP4 | Interview demonstration package | CLOSED / MERGED | runbook and evidence |
| D-093 closure | Final read-only CRC handoff | CLOSED | D093_POST_OLM_HANDOFF_CHECK=PASS |

## Recorded evidence

- Platform CI 36860978223 — SUCCESS.
- S5 Runtime Smoke 36860978155 — SUCCESS.
- S6 Identity Quality Smoke 36840813149 — SUCCESS.
- S7 consumer main commit bc2ba297f0b2807c7168047e3c4ca4c674f942b5 inspected and contract verified.
- D-093 K3/I4 main commit `107ea4d7c651d12295a77d851ab8c2d6c8763fe8`; Platform CI `37224601724` SUCCESS; Operator Kind runtime `37224601718` SUCCESS.
- D-093 I5 Platform Operator main commit `bebb508b5329be158ab790808a09b19b68f89a06`; final Operator image digest `sha256:ee3c1caed1d27642f11e7491a0e46442a08b0b6cb84df4258c4b7f52a8798d73`; Instant Payments product revision `5549750fd010a1df2f14adfc6da49de799c882c2`; CRC consumer #1 closure observed 2026-10-05.
- D-093 I6A main merge `0d1d50ff52cfe1ee1734361db89837f34baec744`; pre-merge final green head `9c4ddb5df7bbd65211d1829a290b624f33a3a2a6`; Platform CI `37587568757` SUCCESS; Operator Kind Runtime `37587568715` SUCCESS.
- D-093 I6B main merge `079b3f11a4b514e636b04bcaf97feabbc3fc66f0`; final PR head `99ab1c25711c91c68dd66f2af0234c874765de5d`; Platform CI `37590409295` SUCCESS; Operator Kind Runtime `37590409355` SUCCESS.
- D-093 I6C main merge `0573eeab564a901f1a25f47467a8aca7d6b8ebea`; validated code head `4918b2e8d2c10d8203fbcf581f963a8a38f80545`; code runs Platform CI `37599472773`, Operator Kind Runtime `37599472784`, OLM Lifecycle `37599472919` SUCCESS; final PR head `83cf5d80f3cd3c3e3d6845c58088e6d7f6b20c0d` runs `37600067342`, `37600067334`, `37600067313` all SUCCESS.

## S5 result

The runtime smoke proves:

~~~text
Kind cluster
  -> shared namespaces
  -> OTel Collector Ready
  -> in-cluster consumer
  -> OTLP HTTP 200
  -> Prometheus exporter exposes factory_consumer_smoke 1
~~~

Allowed claim: CI_RUNTIME_PROVEN_KIND.

## S6 result

Keycloak OIDC discovery and SonarQube readiness were observed successfully.

Allowed claim: CI_RUNTIME_PROVEN_CONTAINER_SMOKE.

## S7 result

The Instant Payments shared-platform overlay, Argo CD Application and ownership document were directly verified, then the product consumed Shared OIDC and Shared OTel on the tested single-node CRC. An actual `payment-orchestrator` trace was observed in the shared collector on 2026-10-03.

Allowed claim: `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`.

Canonical product evidence: `mayabank-instant-payments-resilience-platform/docs/evidence/runtime/I33-I34-crc-shared-platform-tech-lead-20261003.md`.

## D-093 K3/I4 result

The Platform Operator now has a real Kubernetes 1.35 Kind proof.

Observed:
- `CapabilityConsumption` CRD and controller running;
- Manage baseline creation;
- Server-Side Apply field manager;
- resource-profile update;
- drift recovery;
- controller restart recovery;
- brownfield Observe + `OwnershipConflict`;
- explicit adoption after baseline migration;
- `Retain` deletion boundary.

Allowed claim: `KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR`.

Canonical evidence: `evidence/ci/D093-K3-operator-kind-runtime.md`.

## D-093 K3/K4 I5 result

The Platform Operator is now observed on OpenShift Local / CRC 4.22.7 with Instant Payments as brownfield consumer #1.

Observed:
- SCC `restricted-v2` compatibility;
- Observe + OwnershipConflict with zero mutation;
- measured `payments-medium` capacity gate;
- explicit Observe -> Manage transition;
- ResourceQuota, LimitRange, RBAC and baseline NetworkPolicies managed by the Operator;
- zero-window `default-deny` handoff;
- legacy policy removed only after `platform-default-deny` existed;
- Argo CD remained the product workload reconciler and finished `Synced/Healthy`;
- Shared OIDC PASS;
- real payment-orchestrator trace in Shared OTel, trace `0b27a3cc4da1c859c2b488936f45e112`;
- `FINAL_DEMO_RESULT=PASS`.

Allowed claim: `CONSUMER_1_CRC_RUNTIME_PROVEN`.

Canonical evidence: `evidence/runtime/D093-K3-I5-crc-consumer1-instant-payments-20261005.md`.

I6B and I6C are closed on `main`. The combined evidence proves Kind OLM lifecycle plus the previously observed OpenShift controller runtime for consumer #1; it does not prove OpenShift OLM lifecycle. TradeOps consumer #2 remains Observe-only until D-090 G1/G2 and MCP-R5 gates permit Manage.

## D-093 OP1 result

The recruiter-driven Operator-first lane is active.

OP1 packages the existing Go/controller-runtime implementation into a reproducible technical-interview surface:
- CRD and schema validation;
- Reconcile/idempotence;
- Observe/OwnershipConflict/Manage;
- SSA without forced ownership;
- Conditions/Events;
- retry/backoff;
- leader election;
- metrics;
- OLM package markers;
- optional read-only OpenShift inspection.

Canonical runbook: `docs/runbooks/DAAROPS_OPERATOR_FIRST_DEMO.md`.

CI gate: `.github/workflows/d093-op1-operator-interview.yml`.

OP2 OLM lifecycle replay and separate post-OLM handoff completed successfully on CRC on 2026-10-09.

## Current CRC promotion state

Observed on OpenShift Local / CRC 4.22.7:
- shared observability: `CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY`;
- shared realm/OIDC bootstrap: `CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN`;
- API Management consuming shared OIDC + OTel: `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`;
- Instant Payments consuming shared OIDC + OTel: `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`.

Still pending by capability:
- current Argo CD/OpenShift GitOps reconciliation proof;
- SonarQube runtime on CRC;
- HA/multi-node/production.


## A3/A4 — AKS portability promotion — 2026-10-01

Portfolio reference: `cadrage_202682030` D-086.

Status:
- A3 AKS shared-platform runbook: **PREPARED / RUNTIME PENDING**;
- A4 capability consumption contract: **PREPARED / RUNTIME PENDING**.

New references:
- `docs/runbooks/AKS_RUNTIME_VALIDATION.md`;
- `docs/architecture/CAPABILITY_CONSUMPTION_CONTRACT.md`.

Promotion path:

```text
STATIC_VALIDATED
-> AKS cluster qualified by Cluster Factory
-> shared observability bootstrap
-> real consumer
-> CLOUD_RUNTIME_PROVEN_AKS_SHARED_OBSERVABILITY
```

No cloud runtime claim is made until an observed AKS execution exists.


## D-093 final status (2026-10-09)

**D-093 CLOSED / CRC_SCOPE_RUNTIME_PROVEN.** Operator pinned 1/1, Instant Payments Ready, quota storage 20Gi, Argo Synced/Healthy, OP2 temporary resources absent. OLM packaging install-upgrade-uninstall and quota reconstruction proven. CRC single-node is not production HA; no Go controller functional binary upgrade claim. TradeOps remains Observe-only and requires separate approval for Manage.
