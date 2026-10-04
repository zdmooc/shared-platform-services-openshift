# MayaBank Platform Onboarding Operator

Status: **K3 / I2-I3 IMPLEMENTED / CI PENDING / KIND+CRC NOT_PROVEN**

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

## Evidence boundary

I2/I3 source and tests do not yet prove Kind or CRC runtime. Those are separate K3/I4-I5 gates.
