# Hardening & Rollback Runbook — S8

## Hardening controls

- immutable Git history and reviewed changes;
- namespace ownership boundaries;
- no committed credentials;
- explicit dependency classification;
- GitOps prune disabled in generic onboarding templates;
- NetworkPolicy templates for shared-service egress;
- OTel resource limits and probes;
- CI syntax/reference checks;
- runtime evidence separated from design claims.

## Failure cases and rollback

### Shared OTel unavailable

Consumer must continue transaction processing. Telemetry loss must not alter payment correctness. Roll back consumer to the standalone/local observability profile or restore shared collector.

### Shared OIDC unavailable

Do not bypass authorization. Restore the last known-good IAM service/configuration or return controlled authentication/authorization failure.

### SonarQube unavailable

Block or defer the quality stage according to delivery policy; never disable required gates silently.

### GitOps bad promotion

Revert the Git commit or pin the previous revision. Generic consumer templates keep prune disabled by default.

## Stateful services

Kafka/PostgreSQL are excluded from the V1 shared runtime baseline. Product-local rollback remains unchanged.

## Evidence

Each runtime claim must identify:
- commit SHA;
- execution environment;
- expected result;
- observed result;
- rollback result;
- claim boundary.
