# API Management consumer onboarding

**Consumer:** `zdmooc/mayabank-api-management-architecture`  
**Inspected consumer commit:** `00f0fd2b7fc4ffbc95269b57b2c5556339867916`  
**Role:** L3 shared technical platform / API Management specialist.

## Target ownership

The API Management repository owns:
- Kong / API gateway runtime and gateway-specific configuration;
- routes, plugins and gateway policies;
- API lifecycle/governance artefacts;
- OpenAPI/AsyncAPI governance;
- gateway-specific SLOs and operational runbooks.

It does **not** own another copy of the common platform.

## Shared capabilities consumed

- identity / OIDC: `CONSUME_SHARED`;
- observability / OpenTelemetry: `CONSUME_SHARED`;
- secrets / PKI integration: `CONSUME_SHARED`;
- GitOps / Argo CD conventions: `CONSUME_SHARED`;
- quality gates / SonarQube contract: `CONSUME_SHARED`.

## Conditional dependencies

- Kafka/eventing: `REFERENCE_ONLY` from the gateway-platform perspective; a consuming product may use shared Kafka;
- PostgreSQL: `REFERENCE_ONLY` from the gateway-platform perspective; business APIs own their schemas;
- IBM MQ: `SPECIALIZED_PLATFORM` external dependency when legacy/transactional integration requires it.

## Existing standalone proof

The API Management repository already has a bounded CI runtime:

```text
Keycloak 26.8.0
  -> Kong 3.9.3
    -> Payment API
```

GitHub Actions run `36984578912`: **SUCCESS**.

That Keycloak instance is classified **DEDICATED_FOR_TEST** for the standalone CI proof. It is not the target enterprise ownership model.

## Target shared-platform path

```text
shared-platform-services-openshift
  |- shared OIDC / identity contract
  |- shared OTel endpoint
  |- shared secrets integration
  |- shared GitOps / quality conventions
  v
mayabank-api-management-architecture
  |- Kong / gateway policies
  v
business product APIs
```

## Evidence level

Current consumer relationship:

`STATIC_CONSUMER_CONTRACT_VERIFIED`

Runtime consumption of shared OIDC/OTel on CRC remains a separate evidence gate.

## Non-disruption rule

Keep the existing Docker/CI standalone runtime unchanged as a reproducible proof. Add shared-platform consumption as a separate target profile/overlay; do not perform a Big Bang replacement.
