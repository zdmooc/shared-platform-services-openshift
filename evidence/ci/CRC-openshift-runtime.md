# CRC / OpenShift runtime evidence contract

**Status:** PENDING / NOT_PROVEN  
**Date:** 2026-10-01

Execution script:
`scripts/runtime-smoke-openshift.sh`

Runbook:
`docs/runbooks/CRC_RUNTIME_VALIDATION.md`

## Required success markers

- healthy OpenShift ClusterVersion / ClusterOperators preflight;
- shared namespaces created/applied;
- OTel Collector Ready;
- `OTLP_HTTP_STATUS=200`;
- `OTEL_CONSUMER_PATH=PASS`;
- `OPENSHIFT_SHARED_PLATFORM_SMOKE=PASS`.

## Current claim

`CRC_RUNTIME_PROVEN = false`.

No CRC run is inferred from Kind CI.

## Explicit exclusions

Even after a future successful CRC execution, the result will not prove:
- multi-node HA;
- zone/site resilience;
- production Keycloak/SonarQube;
- enterprise PKI/federation;
- shared Kafka/PostgreSQL/MinIO;
- production readiness.
