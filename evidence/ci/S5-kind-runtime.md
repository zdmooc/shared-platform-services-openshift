# S5 — Kind runtime evidence contract

Status at repository creation time: **WORKFLOW_DEFINED / EXECUTION_RESULT_TO_BE_CAPTURED**.

Workflow: `.github/workflows/runtime-smoke.yml`.

Success criteria:
- ephemeral Kind cluster starts;
- platform namespaces are applied;
- OpenTelemetry Collector reaches Ready;
- in-cluster request reaches the Collector Prometheus endpoint;
- the workflow emits `S5_KIND_RUNTIME_SMOKE=PASS`.

Allowed successful claim:
`CI_RUNTIME_PROVEN_KIND_SINGLE_NODE`.

This does **not** prove CRC/OpenShift runtime, HA, multi-node resilience or production readiness.
