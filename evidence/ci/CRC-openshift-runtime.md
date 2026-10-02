# CRC / OpenShift runtime evidence

**Status:** CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY  
**Date:** 2026-10-02  
**Environment:** OpenShift Local / CRC 4.22.7, single-node lab.

Execution script:
`scripts/runtime-smoke-openshift.sh`

Runbook:
`docs/runbooks/CRC_RUNTIME_VALIDATION.md`

## Observed cluster preflight

Observed before the shared-platform smoke:

- current context: `crc-admin`;
- user: `kubeadmin`;
- API: `https://api.crc.testing:6443`;
- ClusterVersion: `4.22.7`, Available=True, Progressing=False;
- ClusterOperators: Available=True, Progressing=False, Degraded=False;
- node `crc`: Ready;
- node roles: control-plane, master, worker.

## Observed shared observability runtime

The first rollout command used a 180-second timeout and returned a timeout while the collector was still starting.

A later direct inspection showed:

~~~text
deployment.apps/otel-collector   1/1   1   1
pod/otel-collector-78bc877b67-kvz46   1/1   Running   0
deployment "otel-collector" successfully rolled out
~~~

The runtime smoke then observed:

~~~text
OTLP_HTTP_STATUS=200
{"partialSuccess":{}}
# HELP factory_consumer_smoke
# TYPE factory_consumer_smoke gauge
factory_consumer_smoke 1
OTEL_CONSUMER_PATH=PASS
~~~

This proves the path:

~~~text
consumer pod
  -> OTLP HTTP
  -> OpenTelemetry Collector
  -> Prometheus exporter
~~~

on the user's real CRC/OpenShift Local cluster.

The rollout timeout has therefore been raised to 600 seconds for CRC first-pull/startup behavior. The original timeout is not reinterpreted as a platform failure because the same deployed collector later reached Ready with zero restarts and the telemetry smoke passed.

## Allowed claim

`CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY`

## Not proved by this result

This result does **not** prove:

- live shared Keycloak/OIDC on CRC;
- SonarQube on CRC;
- Argo CD reconciliation on CRC;
- shared Kafka/PostgreSQL/MinIO;
- API Management consuming shared OIDC/OTel on CRC;
- multi-node HA;
- multi-zone/site resilience;
- production readiness.

The next evidence gate is API Management runtime consumption of shared OIDC and shared OpenTelemetry on CRC.
