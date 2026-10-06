# D-098 — SQY Platform Runtime Consolidation Pack

**Status:** PREPARED / REUSE EXISTING EVIDENCE / NEW RUNTIME EXECUTION PENDING

## Purpose

Consolidate the OpenShift-specific runtime evidence needed for the SQY Expert Kubernetes/OpenShift mission
without rebuilding capabilities already proven by D-093/I5.

## Existing evidence to reuse

- OpenShift Local / CRC 4.22.7;
- Platform Operator running under SCC `restricted-v2`;
- `CapabilityConsumption` brownfield Observe -> explicit Manage;
- quota / LimitRange / RBAC / baseline NetworkPolicies platform-owned;
- Argo product Application Synced/Healthy;
- Shared OIDC validation;
- Shared OTel real trace;
- payment non-regression.

These claims stay bounded to the observed single-node CRC consumer scope.

## SQY-2 consolidation checklist

### Cluster / OpenShift
- [ ] confirm current CRC context and version;
- [ ] capture ClusterOperators and node state;
- [ ] inventory Projects;
- [ ] inventory Routes;
- [ ] capture SCC catalog and effective SCC for selected workload;
- [ ] capture Operator Subscriptions / CSVs / InstallPlans.

### GitOps
- [ ] capture current Argo Applications;
- [ ] map platform-owned vs product-owned resources;
- [ ] reference existing drift/self-heal/prune/rollback evidence;
- [ ] do not re-inject destructive drift into retained workloads.

### Platform Operator
- [ ] capture CRD;
- [ ] capture one `CapabilityConsumption`;
- [ ] capture status/conditions;
- [ ] verify Observe/Manage ownership rules remain documented.

### Helm / Kustomize
- [ ] render selected profiles offline;
- [ ] record chart/kustomize version where applicable;
- [ ] keep render/static proof separate from runtime proof.

## SQY-5 IAM / secrets consolidation

Already available:
- Shared OIDC issuer/realm contract;
- Keycloak specialist runtime;
- external-secret compatibility template;
- IAM secrets runbook.

Remaining mission pack:
- document secret source/owner;
- rotation trigger/frequency;
- emergency revocation path;
- certificate ownership;
- Vault/CyberArk integration boundary;
- negative token tests.

Vault remains an integration pattern unless an actual Vault runtime is executed.

## Observability consolidation

Existing:
- Shared OTel on CRC;
- product Prometheus/Grafana;
- Data Lakehouse Prometheus/Grafana visual proof.

Remaining:
- Alertmanager evidence;
- logging backend evidence;
- one incident correlating alert/metrics/logs.

## Safety

This pack is inventory/replay oriented.
It must not mutate brownfield ownership or scale down retained services merely to generate evidence.

## Gates

- `OPENSHIFT_CAAS_RUNTIME_PACK_READY` after SQY-2 evidence capture.
- `CAAS_SECOPS_OBSERVABILITY_PACK_READY` after SQY-5 evidence capture.
