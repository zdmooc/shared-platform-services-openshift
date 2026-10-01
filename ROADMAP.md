# Roadmap — Shared Platform Services

## V1 / O3 status

| Iteration | Scope | Repository status | Evidence |
|---|---|---|---|
| S0 | Foundation & governance | IMPLEMENTED | STATIC_VALIDATED |
| S1 | GitOps / Argo CD contracts | IMPLEMENTED | STATIC_VALIDATED / CRC_PENDING |
| S2 | Observability shared contracts | IMPLEMENTED | S5 CI_RUNTIME_PROVEN_KIND |
| S3 | IAM / secrets contracts | IMPLEMENTED | STATIC_VALIDATED / CRC_PENDING |
| S4 | Quality / SonarQube contracts | IMPLEMENTED | S6 PROVEN |
| S5 | Kind runtime portability | IMPLEMENTED | CI_RUNTIME_PROVEN_KIND |
| S6 | Keycloak + SonarQube live smoke | IMPLEMENTED | CI_RUNTIME_PROVEN_CONTAINER_SMOKE |
| S7 | Instant Payments onboarding | IMPLEMENTED | STATIC_CONSUMER_CONTRACT_VERIFIED |
| S8 | Hardening / rollback / evidence | IMPLEMENTED | STATIC_VALIDATED |
| O3 | Evidence hardening | COMPLETE | CRC remains pending |

## Recorded evidence

- Platform CI 36860978223 — SUCCESS.
- S5 Runtime Smoke 36860978155 — SUCCESS.
- S6 Identity Quality Smoke 36840813149 — SUCCESS.
- S7 consumer main commit bc2ba297f0b2807c7168047e3c4ca4c674f942b5 inspected and contract verified.

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

The Instant Payments shared-platform overlay, Argo CD Application and ownership document were directly verified.

Allowed claim: STATIC_CONSUMER_CONTRACT_VERIFIED.

## Next promotion gate

CRC/OpenShift is deliberately separate.

A successful CRC execution may promote the Kubernetes-native observability slice to CRC_RUNTIME_PROVEN, but not to HA or production.


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
