# Claim / Evidence Matrix

**Date:** 2026-10-05  
**O3 status:** COMPLETE

| Capability | Repository | Static/CI evidence | CRC/OpenShift | Production |
|---|---|---|---|---|
| Foundation/governance | IMPLEMENTED | Platform CI PASS | N/A | NOT_CLAIMED |
| Argo CD contracts | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| OpenTelemetry Collector | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND | CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY | NOT_CLAIMED |
| Consumer → OTLP → Prometheus path | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND | CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY | NOT_CLAIMED |
| Prometheus integration contract | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| Grafana asset | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| Keycloak/OIDC | IMPLEMENTED_CONTRACT + CRC adapter | CI_RUNTIME_PROVEN_CONTAINER_SMOKE | CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN | NOT_CLAIMED |
| SonarQube | IMPLEMENTED_CONTRACT | CI_RUNTIME_PROVEN_CONTAINER_SMOKE | PENDING | NOT_CLAIMED |
| Instant Payments consumer overlay | IMPLEMENTED / TECH_LEAD_READY | focused CI 37058472014 SUCCESS + OIDC-hardening CI 37065754596 SUCCESS + final Tech Lead CI 37066168907 SUCCESS + frozen-head Tech Lead CI 37066705874 SUCCESS + final global CI 37066705905 SUCCESS | CONSUMER_1_CRC_RUNTIME_PROVEN | NOT_CLAIMED |
| API Management consumer contract | IMPLEMENTED | STATIC_CONSUMER_CONTRACT_VERIFIED | CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER | NOT_CLAIMED |
| Customer/KYC consumer contract | IMPLEMENTED | STATIC_CONSUMER_CONTRACT_VERIFIED | NOT_PROVEN | NOT_CLAIMED |
| Platform Operator / CapabilityConsumption | IMPLEMENTED | ENVTEST_VALIDATED + KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR | CONSUMER_1_CRC_RUNTIME_PROVEN on Instant Payments | NOT_CLAIMED |
| Shared Kafka | DEFERRED | N/A | NOT_DEPLOYED | NOT_CLAIMED |
| Shared PostgreSQL | DEFERRED | N/A | NOT_DEPLOYED | NOT_CLAIMED |
| Shared MinIO | DEFERRED | N/A | NOT_DEPLOYED | NOT_CLAIMED |

## Evidence

### Platform CI
Run 36860978223 — SUCCESS on commit 30c9174f4e12b6d831c2a6d07f725f91d259f835.

### S5 Kind runtime
Run 36860978155 — SUCCESS on the same hardened platform commit.

Observed markers:

~~~text
OTLP_HTTP_STATUS=200
factory_consumer_smoke 1
OTEL_CONSUMER_PATH=PASS
S5_KIND_RUNTIME_SMOKE=PASS
S5_OTLP_CONSUMER_TO_PROMETHEUS=PASS
claim=CI_RUNTIME_PROVEN_KIND
crc_claim=NOT_PROVEN
~~~

### S6 Identity / Quality
Run 36840813149 — SUCCESS.

Allowed claim:
CI_RUNTIME_PROVEN_CONTAINER_SMOKE.

### Instant Payments consumer
Original S7 consumer contract was inspected at commit:
bc2ba297f0b2807c7168047e3c4ca4c674f942b5.

Tech Lead extension evidence now includes:
- Angular/Camel/MongoDB product-owned surfaces;
- shared OIDC + OTel overlay;
- CRC build/bootstrap/evidence scripts;
- focused CI 37058472014 SUCCESS;
- OIDC scope hardening CI 37065754596 SUCCESS;
- global CI 37065452210 SUCCESS after isolating an unrelated Consumer test dependency.

Allowed current claim:
STATIC_CONSUMER_CONTRACT_VERIFIED / READY_FOR_CRC.

### API Management consumer
Consumer main commit inspected:
00f0fd2b7fc4ffbc95269b57b2c5556339867916.

Verified:
- standalone Keycloak + Kong + Payment API runtime exists as a bounded CI proof;
- target ownership keeps Kong/API Management in the specialized platform;
- target identity, observability, secrets, GitOps and quality are declared CONSUME_SHARED;
- standalone Keycloak remains DEDICATED_FOR_TEST and is not promoted as shared-platform ownership.

Existing API Management runtime evidence:
run 36984578912 — SUCCESS.

Allowed platform-consumer claim:
STATIC_CONSUMER_CONTRACT_VERIFIED.

Runtime use of shared OIDC/OTel on CRC is now proven by the API Management consumer profile.

## CRC/OpenShift

CRC shared observability is now `CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY` on OpenShift Local / CRC 4.22.7.

The execution gate exists in:
- scripts/runtime-smoke-openshift.sh
- scripts/run-crc-evidence.sh
- docs/runbooks/CRC_RUNTIME_VALIDATION.md
- evidence/ci/CRC-openshift-runtime.md

Observed on CRC 4.22.7:
- node `crc` Ready;
- all ClusterOperators Available=True / Progressing=False / Degraded=False;
- `otel-collector` deployment 1/1 Ready with zero restarts;
- `OTLP_HTTP_STATUS=200`;
- `factory_consumer_smoke 1`;
- `OTEL_CONSUMER_PATH=PASS`.

Allowed claim:
`CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY`.

SonarQube CRC, Argo CD reconciliation, Kafka/PostgreSQL/MinIO, HA and production remain unproven. Shared Keycloak/OIDC and API Management shared-runtime consumption are now proven on CRC.


### Shared Identity CRC adapter

Implemented on 2026-10-02:
- specialist-runtime reuse contract documented under `platform/identity/keycloak/`;
- shared realm definition `mayabank` added;
- `scripts/deploy-shared-identity-crc.sh` orchestrates the specialist RHBK deployment without copying it;
- `scripts/bootstrap-shared-identity-crc.sh` creates/verifies the shared realm and OIDC discovery;
- Platform CI after the integration: run `36996365594` — SUCCESS.

Allowed current claim: `IMPLEMENTED / STATIC_VALIDATED / CRC_RUNTIME_NOT_PROVEN_SHARED_IDENTITY`.


### Shared Identity CRC runtime proof — 2026-10-02

Observed on OpenShift Local / CRC 4.22.7:

- RHBK Operator 26.6.7-opr.1 installed successfully;
- PostgreSQL lab dependency Running;
- Keycloak CR Ready;
- Keycloak pod Running on node `crc`;
- public Route `keycloak.apps-crc.testing`;
- shared realm `mayabank` created/verified;
- OIDC discovery endpoint returned valid issuer metadata.

Observed proof markers:

```text
SHARED_KEYCLOAK_REALM=PASS
SHARED_OIDC_DISCOVERY=PASS
claim=CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN
```

Allowed claim:
`CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN`.

This proves shared realm/bootstrap + OIDC discovery on CRC. It does not yet prove HA, external IdP federation, production persistence/backup, secret rotation or production readiness.


### API Management shared-platform CRC runtime proof — 2026-10-02

Observed consumer repository: `zdmooc/mayabank-api-management-architecture`.

Observed successful markers:

```text
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```

Observed chain:

```text
Shared Keycloak/OIDC -> Kong -> Payment API
                         |
                         +-> Shared OTel traces
```

Allowed platform-consumer claim:
`CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`.

This does not prove HA, multi-node, production sizing or production readiness.


### Customer/KYC consumer onboarding — 2026-10-02

Consumer:
`zdmooc/mayabank-customer-identity-kyc-digital-banking-architecture`.

Verified:
- explicit `CapabilityConsumption` profile;
- shared OIDC and shared OTel endpoints;
- Kustomize deployable surface;
- opt-in NetworkPolicy contract;
- repository CI gate;
- Shared Platform Argo CD AppProject/Application onboarding assets.

Allowed claim:
`STATIC_CONSUMER_CONTRACT_VERIFIED`.

Runtime remains `NOT_PROVEN` by design; the architecture baseline does not require a heavy Customer/KYC runtime.


### D-093 Platform Operator Kind runtime proof — 2026-10-04

Main commit:
`107ea4d7c651d12295a77d851ab8c2d6c8763fe8`.

Successful main runs:
- Platform CI `37224601724` — SUCCESS;
- D093 K3 Operator Kind Runtime `37224601718` — SUCCESS.

Observed proof markers:

~~~text
K3_KIND_MANAGE=PASS
K3_KIND_SSA_FIELD_MANAGER=PASS
K3_KIND_UPDATE=PASS
K3_KIND_DRIFT_RECOVERY=PASS
K3_KIND_CONTROLLER_RESTART=PASS
K3_KIND_BROWNFIELD_OBSERVE=PASS
K3_KIND_OWNERSHIP_CONFLICT=PASS
K3_KIND_BROWNFIELD_ADOPTION=PASS
K3_KIND_RETAIN=PASS
K3_KIND_OPERATOR_READY=PASS
K3_KIND_RUNTIME_RESULT=PASS
claim=KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR
crc_claim=NOT_PROVEN
~~~

Allowed claim:
`KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR`.

This does not prove CRC/OpenShift, SCC behavior, HA, production or cloud runtime.


### D-093 Platform Operator CRC consumer #1 proof — 2026-10-05

Observed on OpenShift Local / CRC 4.22.7 with Instant Payments:

- Operator image from Shared Platform main `bebb508b5329be158ab790808a09b19b68f89a06`;
- SCC `restricted-v2`;
- Observe reported brownfield ownership conflicts with zero mutation;
- `payments-medium` was introduced after measured usage exceeded generic medium `limits.cpu`;
- explicit Observe -> Manage produced `Ready=True / Reconciled`;
- `platform-quota`, `platform-defaults`, baseline RBAC and platform NetworkPolicies were created;
- legacy `default-deny` coexisted with `platform-default-deny` until the new deny policy was established;
- legacy `default-deny` was then removed and was not recreated;
- Argo CD product Application finished `Synced / Healthy` at product revision `5549750fd010a1df2f14adfc6da49de799c882c2`;
- Shared OIDC checks passed;
- standard payment demo passed;
- real `payment-orchestrator` trace `0b27a3cc4da1c859c2b488936f45e112` was observed in Shared OTel and the collector configuration was restored;
- final Operator usage observed at 1m CPU / 18Mi memory.

Allowed claim:
`CONSUMER_1_CRC_RUNTIME_PROVEN`.

Canonical evidence:
`evidence/runtime/D093-K3-I5-crc-consumer1-instant-payments-20261005.md`.

Boundary: single-node CRC only; HA, production, cloud/AKS and production readiness remain NOT_CLAIMED.
