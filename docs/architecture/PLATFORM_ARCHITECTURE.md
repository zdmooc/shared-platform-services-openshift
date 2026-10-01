# Platform Architecture

## Layering

```text
Infrastructure
  -> OpenShift / Kubernetes
    -> Shared Platform Services
      -> Specialized Platforms
        -> Business / Data / AI Products
```

## Shared capabilities

```text
shared-platform-services
├── GitOps
│   └── Argo CD contracts / AppProjects / ApplicationSets
├── Observability
│   ├── OpenTelemetry
│   ├── Prometheus integration
│   └── Grafana assets
├── IAM & Security
│   ├── OIDC / Keycloak conventions
│   ├── RBAC / NetworkPolicy
│   └── Vault / External Secrets compatibility
└── Software Factory
    ├── SonarQube contract
    ├── reusable CI
    └── immutable artifact / GitOps promotion rules
```

## Consumer boundary

A product owns:
- business code and workflow;
- APIs/events contracts;
- product schemas/topics;
- product-specific SLOs;
- migration scripts;
- product runtime evidence.

The platform owns:
- shared control-plane conventions;
- shared identity and telemetry integration;
- common quality gates;
- reusable platform policies.

## Stateful rule

Kafka, PostgreSQL and object storage are not automatically shared. They remain dedicated when the scenario validates broker/database HA, recovery, performance, isolation or product-specific resilience.

## Truth model

`DESIGNED != IMPLEMENTED != DEPLOYED != RUNTIME_PROVEN`.

Repository S0→S4 completion proves configuration/code presence only. Runtime claims require evidence under `evidence/`.
