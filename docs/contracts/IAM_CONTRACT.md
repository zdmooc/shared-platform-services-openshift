# IAM / OIDC Consumer Contract — S3

## Goal

Applications authenticate against a shared OIDC provider while retaining product-specific roles and authorization rules.

## Platform-owned contract

- issuer lifecycle and availability;
- realm/client naming conventions;
- redirect URI governance;
- signing key rotation process;
- shared identity observability;
- integration path for enterprise IdP federation.

## Product-owned contract

- product roles and scopes;
- endpoint authorization;
- user-to-business-role mapping;
- authorization tests;
- product-specific session requirements.

## Environment variables

```text
OIDC_ISSUER_URI=<shared issuer>
OIDC_CLIENT_ID=<product client>
OIDC_CLIENT_SECRET_FILE=/var/run/secrets/oidc/client-secret
```

Secrets must not be committed to Git.
