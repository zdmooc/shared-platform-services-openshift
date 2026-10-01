# S5 — Kind runtime evidence

**Status:** CI_RUNTIME_PROVEN_KIND  
**Successful run:** 36860978155  
**Commit:** 30c9174f4e12b6d831c2a6d07f725f91d259f835  
**Date:** 2026-10-01

## What was executed

- Kind installed in a runner-writable path;
- ephemeral Kubernetes cluster created;
- shared-platform runtime slice applied;
- shared namespaces created;
- OTel Collector reached Ready;
- an in-cluster consumer sent an OTLP/HTTP metric;
- Collector returned HTTP 200;
- Prometheus exporter exposed the emitted metric;
- cluster was cleaned up automatically.

## Observed evidence

~~~text
OTLP_HTTP_STATUS=200
factory_consumer_smoke 1
OTEL_CONSUMER_PATH=PASS
S5_KIND_RUNTIME_SMOKE=PASS
S5_OTLP_CONSUMER_TO_PROMETHEUS=PASS
claim=CI_RUNTIME_PROVEN_KIND
crc_claim=NOT_PROVEN
~~~

## Allowed claim

CI_RUNTIME_PROVEN_KIND.

## Not proven

- CRC/OpenShift runtime;
- OpenShift Operators;
- multi-node/shared-service HA;
- zone/site resilience;
- production readiness.

The previous failed runs remain useful audit history: the first exposed runner permission assumptions and the second exposed a weak OTLP test payload. Both were corrected before promotion.
