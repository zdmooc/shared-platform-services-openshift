# Shared Identity / Keycloak adapter

## Ownership

`shared-platform-services-openshift` owns the **shared identity contract and realm lifecycle**.

The Keycloak/RHBK runtime implementation remains owned by the specialist repository:

`zdmooc/keycloak-enterprise-roadmap-v7`

This directory deliberately does not duplicate the Operator installation, PostgreSQL lab runtime or Keycloak CR.

## CRC target

For the current OpenShift Local lab:

```text
keycloak-enterprise-roadmap-v7
  -> RHBK Operator
  -> Keycloak CR: keycloak
  -> namespace: keycloak-system
  -> service: keycloak-service
  -> route/hostname: keycloak.apps-crc.testing
       |
       v
shared-platform-services-openshift
  -> shared realm: mayabank
  -> issuer lifecycle contract
       |
       v
specialized-platform consumers
  -> API Management
  -> other products
```

The RHBK Operator creates a Service named `<cr-name>-service` by default. With the current CR name `keycloak`, the in-cluster HTTP endpoint is expected to be:

`http://keycloak-service.keycloak-system.svc:8080`

The public lab issuer is:

`https://keycloak.apps-crc.testing/realms/mayabank`

## Execute after the specialist runtime is Ready

```bash
bash scripts/bootstrap-shared-identity-crc.sh
```

The script:
- refuses non-OpenShift contexts;
- requires the Keycloak CR and service to exist;
- reads the Operator-generated initial admin credential only in memory;
- creates the `mayabank` realm if absent;
- verifies OIDC discovery;
- never prints or commits credentials.

## Evidence boundary

Before execution:
`IMPLEMENTED_CONTRACT / CRC_RUNTIME_NOT_PROVEN_SHARED_IDENTITY`.

After a successful observed run:
the exact Keycloak/OIDC behavior may be promoted separately. It must not be inferred from the existing container CI smoke.
