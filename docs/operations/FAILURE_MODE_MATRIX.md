# Shared Platform Failure Mode Matrix

| Failure | Expected product behavior | Platform action | Claim |
|---|---|---|---|
| OTel Collector unavailable | business flow continues; telemetry degrades | restore collector / endpoint | observability failure must not become payment failure |
| Prometheus unavailable | scrape/history unavailable | restore monitoring | no business retry |
| Grafana unavailable | dashboards unavailable | restore UI | no runtime impact |
| Keycloak/OIDC unavailable | auth fails closed | restore IAM | never bypass auth |
| SonarQube unavailable | quality gate blocked/deferred by policy | restore scanner/server | never silently ignore mandatory gate |
| Argo CD unavailable | running workloads continue | restore control plane | avoid imperative drift |
| Bad GitOps revision | detect and revert | rollback commit/revision | evidence required |
| Shared secret integration unavailable | fail closed for secret-dependent workloads | restore provider/secret | never commit fallback credentials |

Kafka/PostgreSQL are not part of the V1 shared runtime baseline.
