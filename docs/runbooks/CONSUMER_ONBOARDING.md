# Shared Platform Consumer Onboarding Runbook

## Goal

Onboard a product or specialized technical platform without duplicating shared capabilities and without overstating runtime evidence.

## Step 1 — classify the consumer

Choose one:
- `PRODUCT_CONSUMER`;
- `SPECIALIZED_PLATFORM`;
- `REFERENCE_ONLY`.

Document owned capabilities explicitly.

## Step 2 — declare capability consumption

Create a `CapabilityConsumption` contract covering:
- identity;
- observability;
- secrets/PKI;
- GitOps;
- quality;
- eventing;
- database;
- object storage;
- external specialized platforms.

Preferred default for transverse services:
`CONSUME_SHARED`.

## Step 3 — expose a deployable product surface

A consumer that is deployable should expose a stable path such as:

```text
platform-consumption/manifests/
```

The surface must contain no secret values.

## Step 4 — GitOps onboarding

The Shared Platform owns the Argo CD onboarding object.

Rules:
- explicit repository allow-list;
- explicit namespace destination;
- `prune: false` until ownership/recovery is proven;
- `selfHeal: true` only for declarative assets under product ownership;
- no silent namespace creation unless the namespace lifecycle is platform-owned.

## Step 5 — security boundary

- no secrets in Git;
- secret references only;
- least privilege;
- NetworkPolicy must be explicit and opt-in unless a complete product egress model exists;
- identity and telemetry endpoints must point to the shared services;
- specialized platforms remain separate from L2 shared services.

## Step 6 — quality gate

Minimum:
- parse YAML/JSON;
- render Kustomize/Helm;
- secret hygiene;
- validate mandatory shared endpoints;
- product-specific unit/integration tests when code exists.

SonarQube is used when source code and a shared server are available; it is not forced onto architecture-only repositories.

## Step 7 — evidence promotion

Allowed progression:

```text
REFERENCE
  -> IMPLEMENTED
  -> STATIC_VALIDATED
  -> CI_RUNTIME_PROVEN
  -> CRC_RUNTIME_PROVEN
  -> MULTINODE_PROVEN
  -> PRODUCTION_REFERENCE
```

Never infer a higher level from a lower one.

## Current consumers

### API Management

Classification: `SPECIALIZED_PLATFORM`.

Status:
`CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`.

### Customer/KYC/Digital

Classification: `PRODUCT_CONSUMER`.

Status:
`IMPLEMENTED / STATIC_CONSUMER_CONTRACT_VERIFIED`.

The product contract is versioned in both repositories:
- Shared Platform: `consumers/customer-kyc/`;
- Customer/KYC: `platform-consumption/`.

Its runtime remains optional and mission-driven.
