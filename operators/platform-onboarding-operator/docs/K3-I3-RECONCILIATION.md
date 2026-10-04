# K3 / I3 — Reconciliation, ownership and envtest

Status: **IMPLEMENTED / CI PENDING / NO KIND OR CRC CLAIM**

## Reconciliation contract

The controller watches `CapabilityConsumption` plus platform-managed Namespace, ServiceAccount, ResourceQuota, LimitRange, Role, RoleBinding and NetworkPolicy resources.

A managed object is labelled with:

- `platform.mayabank.example/managed-by=mayabank-platform-operator`;
- `platform.mayabank.example/consumer=<consumer>`;
- `platform.mayabank.example/consumption=<CapabilityConsumption name>`.

These labels provide drift event routing without ownerReferences, preserving K2 `deletionPolicy=Retain`.

## Observe

`adoptionPolicy: Observe` performs inventory only.

It reports existing product-owned baselines such as:
- Namespace;
- ResourceQuota;
- LimitRange;
- legacy `default-deny`;
- legacy `allow-dns-egress`.

No platform resource is created or mutated.

## Manage

`adoptionPolicy: Manage` is explicit approval after product-side baseline migration.

The operator uses Server-Side Apply with:

`FieldManager = mayabank-platform-operator`

No ForceOwnership is used.

Existing same-name non-platform-managed resources produce:

`Ready=False / Reason=OwnershipConflict`

The pre-existing Namespace may be adopted in Manage mode by adding only platform-owned labels. Product baseline ResourceQuota/LimitRange/default-deny must be removed from the product desired state before Manage succeeds.

## V1 platform resources

- Namespace labels;
- platform-consumer ServiceAccount;
- baseline read Role/RoleBinding;
- ResourceQuota;
- LimitRange;
- platform-default-deny;
- platform-dns-egress;
- platform-shared-oidc-egress;
- platform-shared-otel-egress.

Product workloads and product-specific NetworkPolicies remain outside this controller.

## Tests

I3 adds envtest coverage for:
- TradeOps-style brownfield Observe conflict;
- greenfield Manage creation + idempotence;
- refusal to overwrite an unowned same-name platform resource.

CI targets Kubernetes 1.35 envtest, matching the Kubernetes generation used by OpenShift 4.22.

Truth boundary: envtest proves API-server/controller behavior, not Kind, CRC, HA or production runtime.
