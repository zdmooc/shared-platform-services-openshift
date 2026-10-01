# Quality Gate Contract — S4

## Common mandatory gates

- repository structure validation;
- YAML/JSON parse validation;
- Kustomize resource reference validation;
- no committed obvious secret material;
- product CI must run unit/integration tests appropriate to its stack;
- SonarQube integration is shared when a server is available;
- immutable image/artifact promotion is preferred over rebuild-per-environment.

## SonarQube

Consumers provide:
- unique project key;
- source/test paths;
- coverage report path;
- exclusions justified by the product;
- `SONAR_HOST_URL` and token from the approved secret mechanism.

The platform owns the shared SonarQube service/integration pattern. Product teams own remediation and coverage relevance.

## Evidence rule

A successful repository CI run proves static repository consistency. It is not a runtime OpenShift proof.
