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
