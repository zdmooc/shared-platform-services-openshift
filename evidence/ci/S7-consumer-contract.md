# S7 — Instant Payments consumer contract evidence

**Consumer:** `zdmooc/mayabank-instant-payments-resilience-platform`

Workflow: `.github/workflows/consumer-contract-smoke.yml`.

## Purpose

Validate the shared-platform integration slice independently from the consumer repository's full product CI.

The workflow:

1. clones the public consumer repository;
2. renders `gitops/overlays/shared-platform`;
3. verifies the shared OTel endpoint and protocol;
4. verifies the Argo CD Application path/repository/namespace;
5. verifies that Kafka and PostgreSQL remain `DEDICATED_FOR_TEST`;
6. verifies that application services remain `PRODUCT_OWNED`.

## Allowed successful claim

`STATIC_CONSUMER_CONTRACT_PROVEN`.

## Not proven

- consumer application build/test;
- live runtime telemetry on Kind/CRC;
- OpenShift Argo CD sync;
- payment correctness;
- Kafka/PostgreSQL HA;
- production shared-platform consumption.

The dedicated workflow intentionally isolates the platform-consumption contract from unrelated product CI failures.
