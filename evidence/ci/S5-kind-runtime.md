# S5 — Kind runtime evidence

**Observed status:** FAILED BEFORE CLUSTER EXECUTION  
**Run:** `36840802013`  
**Date:** 2026-10-01

Workflow: `.github/workflows/runtime-smoke.yml`.

## Observed failure

The original workflow attempted to install Kind directly under `/usr/local/bin` and failed on the hosted runner:

```text
chmod: changing permissions of '/usr/local/bin/kind': Operation not permitted
```

The failure occurred **before** `scripts/runtime-smoke-kind.sh` executed.

Therefore the correct claim for that run is:

`WORKFLOW_IMPLEMENTED / RUNTIME_NOT_PROVEN`.

## Success criteria for the repaired run

- Kind binary installed in a runner-writable directory;
- ephemeral cluster starts;
- shared namespaces are applied;
- OpenTelemetry Collector reaches Ready;
- an in-cluster consumer sends OTLP metric data;
- the Prometheus exporter exposes the emitted metric;
- workflow emits `S5_KIND_RUNTIME_SMOKE=PASS`;
- cluster is destroyed on exit.

Allowed successful claim after an observed green run:

`CI_RUNTIME_PROVEN_KIND`.

Not proven by S5:
- CRC/OpenShift;
- OpenShift Operators;
- multi-zone/site HA;
- production readiness.
