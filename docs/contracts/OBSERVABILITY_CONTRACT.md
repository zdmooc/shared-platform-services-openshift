# Observability Consumer Contract — S2

Products consume the shared telemetry endpoint without surrendering ownership of product SLOs.

## Required environment variables

```text
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.shared-observability.svc:4317
OTEL_SERVICE_NAME=<product-service>
OTEL_RESOURCE_ATTRIBUTES=service.namespace=<product>,deployment.environment=<env>
```

## Required dimensions

- service.name
- service.namespace
- deployment.environment
- correlation.id where appropriate
- product-specific business dimensions with no sensitive payloads

## Platform-owned

- collector endpoint and lifecycle;
- common telemetry ingestion;
- common dashboards/templates;
- shared alerting integration patterns.

## Product-owned

- SLI/SLO definitions;
- business metrics;
- cardinality control;
- trace instrumentation;
- incident thresholds.
