# S6 — Identity & Quality runtime evidence

**Observed status:** CI_RUNTIME_PROVEN_CONTAINER_SMOKE  
**Run:** `36840813149`  
**Date:** 2026-10-01

Workflow: `.github/workflows/identity-quality-smoke.yml`.

## Observed successful checks

- Keycloak dev runtime started;
- OIDC discovery metadata was retrieved successfully;
- SonarQube runtime started;
- SonarQube system status reached UP/GREEN;
- the workflow completed successfully.

Allowed claim:

`CI_RUNTIME_PROVEN_CONTAINER_SMOKE`.

## Explicitly not proven

- CRC/OpenShift Operators;
- enterprise IdP federation;
- secret rotation;
- production persistence/HA;
- enterprise PKI;
- production SonarQube configuration/licensing;
- multi-node failover.

The container smoke proves component startup and the integration endpoints needed by the shared-platform contracts. It is not an OpenShift or production claim.
