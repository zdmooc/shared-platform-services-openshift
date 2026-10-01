# Instant Payments consumer onboarding — S7

Consumer: `zdmooc/mayabank-instant-payments-resilience-platform`

## Shared capabilities consumed in the first integration slice

- OpenTelemetry Collector endpoint: `CONSUME_SHARED`;
- platform observability ownership contract: `CONSUME_SHARED`;
- Argo CD governance: compatible / product repo remains source of product manifests;
- Keycloak/OIDC: contract-aligned, runtime switch remains explicit;
- SonarQube: CI integration contract-aligned.

## Deliberately dedicated

- Kafka payment runtime: `DEDICATED_FOR_TEST`;
- PostgreSQL payment runtime: `DEDICATED_FOR_TEST`.

## Product-owned

- Spring Boot services;
- Angular UI when added;
- Apache Camel integration layer when added;
- MongoDB payment read model when added;
- payment schemas, topics and SLOs.

## Non-disruption rule

The consumer keeps its existing standalone CRC profile. Shared-platform consumption is exposed through a separate overlay so the current runtime evidence remains reproducible.
