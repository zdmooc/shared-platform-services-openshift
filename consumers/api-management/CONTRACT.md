# API Management consumer onboarding

**Consumer:** `zdmooc/mayabank-api-management-architecture`  
**Runtime promotion date:** 2026-10-02  
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

`CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`

Observed on OpenShift Local / CRC 4.22.7:

```text
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```

The claim is bounded to the single-node CRC lab and does not prove HA or production readiness.

## Non-disruption rule

Keep the existing Docker/CI standalone runtime unchanged as a reproducible proof. Add shared-platform consumption as a separate target profile/overlay; do not perform a Big Bang replacement.
