# D-093 I6 — TradeOps consumer #2 Observe CRC runtime evidence

**Date:** 2026-10-07  
**Runtime:** OpenShift Local / CRC single-node  
**Claim:** `D093_TRADEOPS_OBSERVE_CRC_RUNTIME_PROVEN`

## Scope

This evidence proves the TradeOps brownfield onboarding gate in **Observe only**.

The proof intentionally does not authorize or execute `Manage`.

## Observed runtime markers

```text
D093_I6_TRADEOPS_PARK=PASS
D093_I6_OPERATOR_AVAILABLE=PASS
D093_I6_PREEXISTING_CR_POLICY=ABSENT
D093_I6_OBSERVE_INTENT_APPLIED=PASS
D093_I6_OBSERVE_REASON=OwnershipConflict
D093_I6_OWNERSHIP_INVENTORY=PASS
D093_I6_OBSERVE_MANAGED_RESOURCES=ZERO
D093_I6_ZERO_NAMESPACE_MUTATION=PASS
D093_I6_PROTECTED_WORKLOADS_UNCHANGED=PASS
D093_I6_PLATFORM_RESOURCES_CREATED=ZERO
D093_I6_TRADEOPS_OBSERVE=PASS
D093_I6_MANAGE=NOT_AUTHORIZED
```

Raw local evidence bundle:

```text
evidence/out/d093-i6-tradeops-observe-20261007T165931Z
```

## Proven behavior

- TradeOps remained PARKED from the D-090 bounded-window workflow.
- The Platform Operator was available on CRC.
- `CapabilityConsumption/tradeops-crc` was introduced with `adoptionPolicy: Observe`.
- The Operator detected a brownfield ownership conflict.
- Observe created zero managed resource references.
- The canonical before/after namespace snapshot was identical.
- No platform-owned baseline resource was created for `tradeops-crc`.
- Protected TradeOps workloads remained unchanged.
- `Manage` remained explicitly unauthorized.

The detailed ownership-conflict message is retained in the local raw evidence bundle; it is not reconstructed here because it was not part of the captured console transcript used for this sanitized record.

## Ownership boundary

This proof does not transfer:
- Deployments;
- StatefulSets;
- PostgreSQL;
- Redpanda/Kafka;
- Qdrant;
- PVCs;
- Services/Routes;
- product-specific NetworkPolicies;
- product secrets or application configuration.

## Claim boundary

Allowed:

```text
D093_TRADEOPS_OBSERVE_CRC_RUNTIME_PROVEN
```

Not implied:
- Manage adoption;
- platform ownership of TradeOps baseline resources;
- zero-double-ownership Manage handoff;
- production or HA readiness.

Next canonical gate: **D-092 MCP-R5 native MCP -> IBM MQ live CRC proof**.
