# S7 — Instant Payments consumer contract evidence

**Consumer:** `zdmooc/mayabank-instant-payments-resilience-platform`  
**Consumer main commit inspected:** `bc2ba297f0b2807c7168047e3c4ca4c674f942b5`  
**Verification date:** 2026-10-01

## Verified files

Direct repository inspection confirmed:

- `gitops/overlays/shared-platform/kustomization.yaml`
  - points application telemetry to `http://otel-collector.shared-observability.svc:4317`;
  - sets `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`;
  - labels workloads with `platform.mayabank.example/observability=shared`.
- `gitops/argocd/application-shared-platform.yaml`
  - references the current consumer repository;
  - points to `gitops/overlays/shared-platform`;
  - targets `instant-payments-local`.
- `docs/platform/SHARED-PLATFORM-CONSUMPTION.md`
  - Kafka payment runtime remains `DEDICATED_FOR_TEST`;
  - PostgreSQL payment runtime remains `DEDICATED_FOR_TEST`;
  - application services remain `PRODUCT_OWNED`.

Observed blob SHAs at verification time:
- overlay: `517b71fb92cf1d3db3c2291644f2628ba6cd6ec6`;
- Argo CD Application: `3c2a25147240ff3788350de10472f7760bc7c468`;
- consumption document: `1e24f02617630142b89a17b8795723767e764b83`.

## CI limitation

A cross-repository GitHub Actions smoke was attempted from the shared-platform repository but the repository-scoped `GITHUB_TOKEN` could not clone the consumer repository.

That workflow was removed rather than leaving a permanently failing CI gate or introducing a broad PAT merely for portfolio evidence.

## Allowed claim

`STATIC_CONSUMER_CONTRACT_VERIFIED`.

## Not proven

- full consumer product CI;
- live runtime telemetry on Kind/CRC from the real payment service;
- OpenShift Argo CD sync;
- payment correctness;
- Kafka/PostgreSQL HA;
- production shared-platform consumption.

Runtime promotion still requires the shared platform and consumer workload to execute together and produce observed telemetry.
