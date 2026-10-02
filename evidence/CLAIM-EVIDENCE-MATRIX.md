# Claim / Evidence Matrix

**Date:** 2026-10-02  
**O3 status:** COMPLETE

| Capability | Repository | Static/CI evidence | CRC/OpenShift | Production |
|---|---|---|---|---|
| Foundation/governance | IMPLEMENTED | Platform CI PASS | N/A | NOT_CLAIMED |
| Argo CD contracts | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| OpenTelemetry Collector | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND | CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY | NOT_CLAIMED |
| Consumer → OTLP → Prometheus path | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND | CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY | NOT_CLAIMED |
| Prometheus integration contract | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| Grafana asset | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| Keycloak/OIDC | IMPLEMENTED_CONTRACT + CRC adapter | CI_RUNTIME_PROVEN_CONTAINER_SMOKE | CRC_SHARED_IDENTITY_PENDING | NOT_CLAIMED |
| SonarQube | IMPLEMENTED_CONTRACT | CI_RUNTIME_PROVEN_CONTAINER_SMOKE | PENDING | NOT_CLAIMED |
| Instant Payments consumer overlay | IMPLEMENTED | STATIC_CONSUMER_CONTRACT_VERIFIED | PENDING | NOT_CLAIMED |
| API Management consumer contract | IMPLEMENTED | STATIC_CONSUMER_CONTRACT_VERIFIED | PENDING | NOT_CLAIMED |
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
Consumer main commit inspected:
bc2ba297f0b2807c7168047e3c4ca4c674f942b5.

Verified shared-platform overlay, Argo CD Application and dependency ownership.

Allowed claim:
STATIC_CONSUMER_CONTRACT_VERIFIED.

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

Runtime use of shared OIDC/OTel on CRC remains pending.

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

Shared Keycloak/OIDC, SonarQube, Argo CD reconciliation, Kafka/PostgreSQL/MinIO, API Management shared-runtime consumption, HA and production remain unproven.


### Shared Identity CRC adapter

Implemented on 2026-10-02:
- specialist-runtime reuse contract documented under `platform/identity/keycloak/`;
- shared realm definition `mayabank` added;
- `scripts/deploy-shared-identity-crc.sh` orchestrates the specialist RHBK deployment without copying it;
- `scripts/bootstrap-shared-identity-crc.sh` creates/verifies the shared realm and OIDC discovery;
- Platform CI after the integration: run `36996365594` — SUCCESS.

Allowed current claim: `IMPLEMENTED / STATIC_VALIDATED / CRC_RUNTIME_NOT_PROVEN_SHARED_IDENTITY`.
