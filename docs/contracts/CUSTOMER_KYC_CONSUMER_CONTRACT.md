# Customer/KYC — Shared Platform Contract

## Contract

```text
Shared Platform L2
  |- OIDC / realm mayabank
  |- OpenTelemetry
  |- GitOps contract
  |- secret/PKI pattern
  |- quality contract
  |
  +--> Customer/KYC product
         |- customer-domain
         |- onboarding
         |- KYC/KYB
         |- consent/preferences
         |- Customer 360
```

API Management, Kafka and IBM MQ remain specialized L3 platforms rather than being duplicated inside the product.

## GitOps

The product deployable surface is:
`platform-consumption/manifests`.

The platform onboarding Application is:
`gitops/consumers/customer-kyc-application.yaml`.

## Security

The product consumer profile contains no client secret. Secret material must come from the approved shared secret mechanism.

The provided NetworkPolicy is opt-in using:
`platform.mayabank.example/shared-egress-client=true`.

This avoids imposing an accidental deny-all egress policy on workloads that have not yet adopted the contract.

## Evidence

Current evidence level:
`IMPLEMENTED / STATIC_CONSUMER_CONTRACT_VERIFIED`.

Runtime deployment is explicitly separate.
