# Instant Payments consumer onboarding — S7

Consumer: `zdmooc/mayabank-instant-payments-resilience-platform`

## Shared capabilities consumed

- OpenTelemetry Collector endpoint: `CONSUME_SHARED`;
- platform observability ownership contract: `CONSUME_SHARED`;
- Argo CD governance: compatible; product repository remains source of product manifests;
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

The consumer keeps its existing standalone CRC profile.

Shared-platform consumption is exposed through a separate overlay so existing runtime evidence remains reproducible and no Big Bang migration is implied.

## Evidence

Direct inspection of consumer main commit `bc2ba297f0b2807c7168047e3c4ca4c674f942b5` verified the shared-platform overlay, Argo CD Application and dependency-ownership document.

Current allowed claim:

`STATIC_CONSUMER_CONTRACT_VERIFIED`.

The consumer repository's broader CI is not used as evidence for this narrow platform contract because it currently contains unrelated failing jobs.

Runtime trace/metric proof on OpenShift/CRC remains a separate gate.
