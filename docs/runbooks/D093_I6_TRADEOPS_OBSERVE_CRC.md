# D-093 I6 — TradeOps brownfield Observe on CRC

Status: **IMPLEMENTED / CI VALIDATION TARGETED / CRC RUNTIME PENDING**

## Goal

Onboard TradeOps as Platform Operator consumer #2 in **Observe only**.

This gate inventories ownership conflicts without transferring ownership or mutating the TradeOps namespace baseline.

Canonical sequence:

```text
D-090 G2 CLOSED
 -> D-093 I6 TradeOps Observe
 -> refresh brownfield capacity / ownership
 -> MCP-R5
 -> explicit Manage decision only if safe
```

## Preconditions

- TradeOps remains PARKED after the D-090 bounded windows;
- `CapabilityConsumption` CRD exists;
- `mayabank-platform-operator` is Available in namespace `shared-platform-services`;
- namespace `tradeops` exists;
- no pre-existing `CapabilityConsumption/tradeops-crc` may already be in `Manage`.

## Observe intent

File:

```text
consumers/tradeops/capability-consumption-crc-observe.yaml
```

Key lifecycle boundary:

```yaml
lifecycle:
  adoptionPolicy: Observe
  deletionPolicy: Retain
```

The provisional `ai-medium` profile is **not** Manage approval. Resource sizing must be refreshed from the real brownfield inventory before any later Manage transition.

## Protected product ownership

Observe must not transfer or mutate:

- TradeOps Deployments;
- TradeOps StatefulSets;
- PostgreSQL;
- Redpanda/Kafka;
- Qdrant;
- PVCs;
- Services/Routes;
- product-specific NetworkPolicies;
- product secrets;
- application configuration.

The Operator itself is designed to materialize only the common platform baseline in Manage. Observe must produce zero managed resource references.

## Execute

```bash
cd /c/workspaces/shared-platform-services-openshift

git switch main
git pull --ff-only origin main
git log -5 --oneline

bash scripts/d093-i6-tradeops-observe-crc.sh
```

The script resolves the sibling TradeOps repository by default:

```text
../TradeOps-GenAI-Integration
```

Override when needed:

```bash
export TRADEOPS_REPO=/c/workspaces/TradeOps-GenAI-Integration
```

## Zero-mutation proof

Before applying the Observe CR, the script creates a canonical snapshot of:

- Namespace metadata/spec;
- Deployments;
- StatefulSets;
- Services;
- PVCs;
- NetworkPolicies;
- ResourceQuotas;
- LimitRanges;
- ServiceAccounts;
- Roles;
- RoleBindings.

Runtime/status-only metadata such as resourceVersion, UID and managedFields is excluded.

The same snapshot is taken after Observe. The hashes must match exactly.

## Accepted Observe outcomes

The Operator Ready reason may be:

```text
OwnershipConflict
```

when existing product-owned baseline resources are detected, or:

```text
ObserveMode
```

when no ownership conflict exists.

Both are valid Observe outcomes **only if zero namespace mutation is proven**.

The ownership message is captured as evidence for the later handoff decision.

## Required markers

```text
D093_I6_TRADEOPS_PARK=PASS
D093_I6_OPERATOR_AVAILABLE=PASS
D093_I6_OBSERVE_INTENT_APPLIED=PASS
D093_I6_OWNERSHIP_INVENTORY=PASS
D093_I6_OBSERVE_MANAGED_RESOURCES=ZERO
D093_I6_ZERO_NAMESPACE_MUTATION=PASS
D093_I6_PROTECTED_WORKLOADS_UNCHANGED=PASS
D093_I6_PLATFORM_RESOURCES_CREATED=ZERO
D093_I6_TRADEOPS_OBSERVE=PASS
D093_I6_MANAGE=NOT_AUTHORIZED
```

## Evidence

Local raw evidence is written under:

```text
evidence/out/d093-i6-tradeops-observe-<UTC timestamp>/
```

That directory is gitignored. Only sanitized evidence is promoted after review.

## Claim boundary

A successful run may promote only:

```text
D093_TRADEOPS_OBSERVE_CRC_RUNTIME_PROVEN
```

It does not promote:
- TradeOps Manage;
- common baseline ownership transfer;
- multi-node/HA behavior;
- production readiness.

Manage remains an explicit later decision after refreshed brownfield capacity, ownership and non-regression review.
