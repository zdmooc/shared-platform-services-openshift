# IAM & Secrets Runbook — S3

## Keycloak/OIDC

The repository provides realm/client conventions, not a claim that a Keycloak runtime is already deployed.

1. Provision or identify the approved shared OIDC provider.
2. Create one product client with least privilege.
3. Keep roles/scopes product-owned.
4. Store client credentials outside Git.
5. Configure product with the issuer/client contract.
6. Test token validation, expiry, invalid audience and insufficient-role cases.

## Secrets

`platform/security/secrets/external-secret-template.yaml` is a compatibility template. Apply it only when External Secrets Operator and the referenced SecretStore exist.

Vault/CyberArk/enterprise PKI remain integration boundaries until real infrastructure is available.

## Evidence

Record issuer metadata (without secrets), client ID, token-validation tests and the exact cluster context.
