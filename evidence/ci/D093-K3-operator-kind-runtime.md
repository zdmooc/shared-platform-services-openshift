# D-093 K3 / I4 — Platform Operator Kind runtime evidence

**Date:** 2026-10-04  
**Status:** `KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR`  
**Main commit:** `107ea4d7c651d12295a77d851ab8c2d6c8763fe8`  
**Runtime workflow:** `D093 K3 Operator Kind Runtime`  
**Successful main run:** `37224601718`  
**Platform CI main run:** `37224601724` — SUCCESS

## Runtime target

- Kind `v0.33.0`;
- Kubernetes node image `kindest/node:v1.35.8`;
- `CapabilityConsumption` CRD `platform.mayabank.example/v1alpha1`;
- Go/controller-runtime Platform Operator;
- image built from repository source and loaded into the ephemeral Kind cluster.

## Observed scenarios

The successful run observed:

~~~text
K3_KIND_MANAGE=PASS
K3_KIND_SSA_FIELD_MANAGER=PASS
K3_KIND_UPDATE=PASS
K3_KIND_DRIFT_RECOVERY=PASS
K3_KIND_CONTROLLER_RESTART=PASS
K3_KIND_BROWNFIELD_OBSERVE=PASS
K3_KIND_OWNERSHIP_CONFLICT=PASS
K3_KIND_BROWNFIELD_ADOPTION=PASS
K3_KIND_RETAIN=PASS
K3_KIND_OPERATOR_READY=PASS
K3_KIND_RUNTIME_RESULT=PASS
claim=KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR
crc_claim=NOT_PROVEN
~~~

## What was proven

### Greenfield / Manage

A `CapabilityConsumption` created a platform baseline including:
- Namespace;
- ServiceAccount;
- Role / RoleBinding;
- ResourceQuota;
- LimitRange;
- baseline NetworkPolicies.

The CR reached `Ready=True / Reason=Reconciled`.

### Server-Side Apply

`ResourceQuota/platform-quota` exposed a `managedFields` entry with:
- manager: `mayabank-platform-operator`;
- operation: `Apply`.

No forced ownership is used by the V1 controller.

### Update

Changing the declared resource profile from `small` to `medium` changed the managed quota from `requests.cpu=2` to `requests.cpu=4`.

### Drift recovery

Deleting the managed `ResourceQuota/platform-quota` caused the controller to recreate it with the declared profile.

### Controller restart

After a Deployment restart, deleting the managed `LimitRange/platform-defaults` caused it to be recreated and the CR returned to `Reconciled`.

### Brownfield Observe / ownership conflict

A TradeOps-shaped existing namespace with product-owned ResourceQuota, LimitRange and `default-deny` NetworkPolicy was inspected in `Observe` mode.

The CR reported:
- `Ready=False`;
- `Reason=OwnershipConflict`.

The Operator did not create `platform-quota` in Observe mode.

### Explicit adoption

After explicit removal of the old product-owned baseline objects and transition to `Manage`, the Operator reconciled the platform baseline successfully.

### Retain

Deleting the brownfield `CapabilityConsumption` kept:
- the Namespace;
- `ResourceQuota/platform-quota`;
- other platform baseline resources.

This validates the V1 `deletionPolicy=Retain` boundary.

## Allowed claim

`KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR`.

## Not proven

- CRC/OpenShift Operator runtime;
- SCC/OpenShift-specific behavior;
- Instant Payments through the Operator on CRC;
- TradeOps brownfield adoption on CRC;
- multi-node HA;
- production readiness;
- AKS/cloud runtime.
