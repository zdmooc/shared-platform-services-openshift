# Claim / Evidence Matrix

**Date:** 2026-10-01  
**O3 status:** COMPLETE

| Capability | Repository | Static/CI evidence | CRC/OpenShift | Production |
|---|---|---|---|---|
| Foundation/governance | IMPLEMENTED | Platform CI PASS | N/A | NOT_CLAIMED |
| Argo CD contracts | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| OpenTelemetry Collector | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND | PENDING | NOT_CLAIMED |
| Consumer → OTLP → Prometheus path | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND | PENDING | NOT_CLAIMED |
| Prometheus integration contract | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| Grafana asset | IMPLEMENTED | STATIC_VALIDATED | PENDING | NOT_CLAIMED |
| Keycloak/OIDC | IMPLEMENTED_CONTRACT | CI_RUNTIME_PROVEN_CONTAINER_SMOKE | PENDING | NOT_CLAIMED |
| SonarQube | IMPLEMENTED_CONTRACT | CI_RUNTIME_PROVEN_CONTAINER_SMOKE | PENDING | NOT_CLAIMED |
| Instant Payments consumer overlay | IMPLEMENTED | STATIC_CONSUMER_CONTRACT_VERIFIED | PENDING | NOT_CLAIMED |
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

### S7 Consumer
Consumer main commit inspected:
bc2ba297f0b2807c7168047e3c4ca4c674f942b5.

Verified overlay, Argo CD Application and ownership document.

Allowed claim:
STATIC_CONSUMER_CONTRACT_VERIFIED.

## CRC/OpenShift

CRC runtime remains PENDING / NOT_PROVEN.

The execution gate exists in:
- scripts/runtime-smoke-openshift.sh
- docs/runbooks/CRC_RUNTIME_VALIDATION.md
- evidence/ci/CRC-openshift-runtime.md

No Kind or container-smoke result is promoted to CRC, HA or production evidence.
