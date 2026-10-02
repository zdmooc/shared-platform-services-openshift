# Customer/KYC consumer onboarding

**Consumer:** `zdmooc/mayabank-customer-identity-kyc-digital-banking-architecture`  
**Role:** business/product architecture consumer  
**Onboarding status:** `IMPLEMENTED / STATIC_CONSUMER_CONTRACT_VERIFIED`

## Ownership

The Customer/KYC product owns:
- Customer 360 and customer-domain semantics;
- onboarding/KYC/KYB business state;
- consent/preference business rules;
- product API/event contracts;
- product data/schema decisions;
- product NFR/SLO requirements.

It does not own another copy of the common technical platform.

## Shared capabilities consumed

- OpenShift/Kubernetes conventions: `CONSUME_SHARED`;
- GitOps / Argo CD conventions: `CONSUME_SHARED`;
- shared OIDC issuer/realm: `CONSUME_SHARED`;
- shared OpenTelemetry: `CONSUME_SHARED`;
- secrets/PKI contract: `CONSUME_SHARED`;
- quality gate contract: `CONSUME_SHARED`.

## Specialized platforms

- API Management: `SPECIALIZED_PLATFORM`;
- event streaming/Kafka: `SPECIALIZED_PLATFORM` when required;
- IBM MQ: `SPECIALIZED_PLATFORM` for legacy integration.

## Concrete consumer assets

Consumer repository path: `platform-consumption/`.

The profile contains:
- capability-consumption contract;
- namespace;
- shared endpoint ConfigMap;
- opt-in NetworkPolicy;
- Kustomize surface;
- CI validation workflow.

## GitOps onboarding

The Shared Platform repository owns the Argo CD onboarding contract under:
`gitops/consumers/customer-kyc-application.yaml`.

The Application points to the consumer repository's deployable `platform-consumption/manifests` surface.

## Evidence boundary

Allowed claim:
`STATIC_CONSUMER_CONTRACT_VERIFIED`.

No Customer/KYC runtime is claimed until an actual target deployment is observed.
