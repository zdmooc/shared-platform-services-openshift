# MayaBank Platform Onboarding Operator

Status: **K3 / I2-I4 IMPLEMENTED / ENVTEST VALIDATED / KIND_RUNTIME_PROVEN / CRC NOT_PROVEN**

This operator materializes D-093/K2. `CapabilityConsumption` is the canonical Kubernetes Platform API.

## Implemented

- Go/Kubebuilder-compatible project layout;
- `platform.mayabank.example/v1alpha1` CRD;
- status/conditions/events;
- `Observe` and `Manage` lifecycle;
- non-destructive ownership conflict reporting;
- Server-Side Apply field manager `mayabank-platform-operator`;
- label-based watches for continuous reconciliation without garbage-collection ownerReferences;
- platform-owned Namespace labels, RBAC, ResourceQuota, LimitRange and baseline NetworkPolicies;
- `Retain` deletion boundary;
- envtest scenarios for brownfield Observe, greenfield Manage/idempotence and overwrite refusal.

## Brownfield rule

```text
Observe
 -> inventory / compare
 -> OwnershipConflict if product baseline still exists
 -> explicit migration in product Git
 -> Manage
 -> SSA without ForceOwnership
```

The operator does not deploy business workloads. Product Git + Argo CD retain Deployments, StatefulSets, Services, Routes, stateful dependencies and product-specific NetworkPolicies.

## I4 Kind runtime evidence

Main commit: `107ea4d7c651d12295a77d851ab8c2d6c8763fe8`.

Successful runs:
- Platform CI `37224601724` — SUCCESS;
- D093 K3 Operator Kind Runtime `37224601718` — SUCCESS.

Observed runtime markers include Manage, Server-Side Apply field ownership, profile update, drift recovery, controller restart, brownfield Observe/OwnershipConflict, explicit adoption and Retain deletion behavior.

Canonical evidence: `evidence/ci/D093-K3-operator-kind-runtime.md`.

Allowed claim: `KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR`.

## Evidence boundary

Kind validates Kubernetes runtime behavior for this Operator. CRC/OpenShift behavior, SCC/OpenShift-specific constraints, consumer #1/#2 integration on CRC, HA, production and cloud runtime remain unproven.


## Resource profiles

The Operator keeps generic and workload-class profiles separate.

- `small`: requests 2 CPU / 4Gi, limits 4 CPU / 8Gi, 4 PVC, 10Gi storage.
- `medium`: requests 4 CPU / 8Gi, limits 8 CPU / 16Gi, 6 PVC, 20Gi storage.
- `payments-medium`: requests 4 CPU / 8Gi, limits 12 CPU / 16Gi, 6 PVC, 20Gi storage.
- `ai-medium`: requests 6 CPU / 10Gi, limits 16 CPU / 24Gi, 8 PVC, 20Gi storage.

`payments-medium` was introduced during D-093/I5 after the Instant Payments CRC pre-Manage measurement showed 19 active pods with about 505m CPU requests, 3.2Gi memory requests, 9.15 CPU limits, 9.44Gi memory limits, four PVCs and 5Gi requested storage. The generic `medium` profile would have set `limits.cpu=8`, below existing declared usage, which could block a later pod replacement or rollout.

This profile change does not itself prove CRC Manage. Runtime promotion still requires the explicit Observe -> Manage handoff and post-handoff non-regression evidence.
