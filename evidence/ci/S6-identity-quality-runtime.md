# S6 — Identity & Quality runtime evidence contract

Status at repository creation time: **WORKFLOW_DEFINED / EXECUTION_RESULT_TO_BE_CAPTURED**.

Workflow: `.github/workflows/identity-quality-smoke.yml`.

Success criteria:
- Keycloak dev runtime exposes OIDC discovery metadata;
- SonarQube runtime reaches UP/GREEN;
- workflow emits both PASS markers.

Allowed successful claim:
`CI_RUNTIME_PROVEN_CONTAINER_SMOKE`.

Not proven:
- CRC/OpenShift Operators;
- enterprise IdP federation;
- secret rotation;
- production persistence/HA;
- enterprise SonarQube license/configuration;
- production PKI.
