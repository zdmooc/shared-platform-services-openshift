# Shared Platform Capability Consumption Contract

**Date:** 2026-10-02  
**Status:** CONSUMER CONTRACT BASELINE / RUNTIME PROMOTION PER CONSUMER

Every consumer declares the technical capabilities it needs before introducing another local platform instance.

## Contract

```yaml
apiVersion: platform.mayabank.example/v1alpha1
kind: CapabilityConsumption
metadata:
  name: example-consumer
spec:
  identity:
    mode: CONSUME_SHARED
  observability:
    mode: CONSUME_SHARED
  secrets:
    mode: CONSUME_SHARED
  gitops:
    mode: CONSUME_SHARED
  quality:
    mode: CONSUME_SHARED
  eventing:
    mode: DEDICATED_FOR_TEST
  database:
    mode: DEDICATED_FOR_TEST
  objectStorage:
    mode: REFERENCE_ONLY
```

Allowed modes:

- `CONSUME_SHARED`
- `DEDICATED_FOR_TEST`
- `SPECIALIZED_PLATFORM`
- `PRODUCT_OWNED`
- `REFERENCE_ONLY`

## Capability meanings

### identity
Default: `CONSUME_SHARED`.

The consumer receives OIDC/OAuth2 conventions, client/realm integration contract and identity endpoint configuration. Product-specific authorization rules remain product-owned.

### observability
Default: `CONSUME_SHARED`.

The consumer emits standard telemetry once, preferably through OpenTelemetry. The platform owns the shared collector/backend integration; the consumer owns business/platform-specific metrics, SLOs and correlation semantics.

### secrets
Default: `CONSUME_SHARED`.

The platform provides the secret-management integration contract. No static cloud credential is committed to Git.

### gitops
Default: `CONSUME_SHARED`.

The platform owns Argo CD governance conventions, AppProject/ApplicationSet contracts and promotion rules. The consumer keeps ownership of its deployable manifests and release intent.

### quality
Default: `CONSUME_SHARED`.

The platform owns the reusable quality-gate/SonarQube integration contract. The consumer owns stack-specific tests, coverage relevance and remediation.

### eventing
Default depends on the proof.

Use `CONSUME_SHARED` for ordinary application eventing. Use `DEDICATED_FOR_TEST` when Kafka/broker failover, recovery, topology or performance is the subject of the scenario. Use `REFERENCE_ONLY` when the consumer does not itself require eventing at runtime.

### database
Default depends on the proof.

Use `CONSUME_SHARED` for ordinary persistence. Use `DEDICATED_FOR_TEST` for HA, PITR, crash-window, recovery, performance or correctness tests. Use `REFERENCE_ONLY` when persistence belongs to a downstream product rather than the consuming platform.

### objectStorage
Use shared S3/object storage when it is a dependency. Keep it dedicated when storage behavior itself is under test.

## Specialized platform rule

A shared technical platform such as API Management or IBM MQ may itself be a consumer of L2 shared services while owning its specialist runtime.

```text
Shared Platform Services (L2)
  -> identity / observability / secrets / GitOps / quality
       -> API Management (L3, SPECIALIZED_PLATFORM)
            -> business products
```

This does not make Kong, IBM MQ or another specialist engine part of the L2 common platform.

## Environment neutrality

The contract is logical and portable.

```text
Kind / CRC / AKS / GKE / EKS / ARO
        |
        v
same capability intent
        |
        v
environment-specific implementation
```

Cloud-specific products do not leak into business code unless an ADR explicitly accepts the coupling.

## Evidence

A declared contract is only `STATIC_CONSUMER_CONTRACT_VERIFIED` until the consumer successfully resolves and uses the capability in runtime.
