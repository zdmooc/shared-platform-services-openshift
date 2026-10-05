# D-093 / K3 I5 — Instant Payments consumer #1 CRC runtime evidence

**Date:** 2026-10-05  
**Runtime:** OpenShift Local / CRC 4.22.7, single node  
**Claim:** `CONSUMER_1_CRC_RUNTIME_PROVEN`

## Scope

This evidence closes D-093 K3/I5 by proving the `CapabilityConsumption` Platform Operator on OpenShift/CRC with Instant Payments as brownfield consumer #1.

The proof covers:
- OpenShift/SCC-compatible Operator runtime;
- brownfield `Observe` with no mutation;
- explicit `Observe -> Manage` transition;
- controlled ownership transfer without a NetworkPolicy-open window;
- platform-owned ResourceQuota, LimitRange, baseline RBAC and NetworkPolicies;
- product workload ownership retained by Argo CD;
- Shared OIDC and Shared OTel non-regression;
- payment runtime non-regression.

## Operator runtime

Observed before Manage:
- Operator Deployment `1/1 Running`;
- OpenShift SCC `restricted-v2`;
- controller-runtime logger initialized;
- `CapabilityConsumption/instant-payments-crc` remained `Observe`;
- legacy `NetworkPolicy/default-deny` existed;
- `platform-default-deny` did not exist;
- zero-mutation checks passed.

## Capacity gate

Current Instant Payments declared usage before Manage:
- active pods: 19;
- requests.cpu: 505m;
- requests.memory: 3200Mi;
- limits.cpu: 9150m;
- limits.memory: 9664Mi;
- PVC: 4;
- requested storage: 5Gi.

The generic `medium` profile would have imposed `limits.cpu=8`, below observed usage. D-093 therefore introduced `payments-medium` without widening the generic profile:

```text
requests.cpu       4
requests.memory    8Gi
limits.cpu         12
limits.memory      16Gi
PVC                6
requests.storage   20Gi
```

Template audit before Manage: `MISSING_CONTAINERS=0`.

## Manage transition

Observed immediately after explicit transition:

```text
Ready=True
Reason=Reconciled
AdoptionReady=True
Reason=Managed
```

Observed quota:

```text
persistentvolumeclaims  4 / 6
requests.cpu            505m / 4
requests.memory         3200Mi / 8Gi
requests.storage        5Gi / 20Gi
limits.cpu              9150m / 12
limits.memory           9664Mi / 16Gi
```

Platform-owned resources included:
- `ResourceQuota/platform-quota`;
- `LimitRange/platform-defaults`;
- `NetworkPolicy/platform-default-deny`;
- `NetworkPolicy/platform-dns-egress`;
- `NetworkPolicy/platform-shared-oidc-egress`;
- `NetworkPolicy/platform-shared-otel-egress`;
- baseline ServiceAccount/RBAC.

All platform resources were labeled with consumption `instant-payments-crc`.

## Zero-window NetworkPolicy handoff

During handoff both deny policies coexisted:

```text
default-deny
platform-default-deny
```

Only after `Ready=True / Reconciled` was observed was legacy `default-deny` deleted.

After Argo refresh:

```text
legacy default-deny absent
platform-default-deny managed-by=mayabank-platform-operator
sync=Synced
health=Healthy
revision=5549750fd010a1df2f14adfc6da49de799c882c2
```

No double ownership remained.

## Non-regression

Shared OIDC:
- render PASS;
- OIDC discovery PASS;
- JWK secret PASS;
- token PASS;
- token scopes PASS.

Payment runtime:
- all main application deployments Ready;
- `FINAL_DEMO_READINESS=PASS`;
- `FINAL_DEMO_PAYMENT_SAFETY=PASS`;
- `FINAL_DEMO_CONSUMER=PASS`;
- `FINAL_DEMO_ACCEPTOR=PASS`;
- `FINAL_DEMO_CORRELATION=PASS`;
- `FINAL_DEMO_METRICS_OBSERVABILITY=PASS`;
- `FINAL_DEMO_RESULT=PASS`.

Shared OTel:
- OTLP-enabled payment-orchestrator image verified;
- authenticated product request generated;
- real `payment-orchestrator` trace observed in Shared OTel;
- trace ID `0b27a3cc4da1c859c2b488936f45e112`;
- `I33_PAYMENT_SHARED_OTEL=PASS`;
- Shared OTel Collector configuration restored successfully.

## Final snapshot

```text
CapabilityConsumption instant-payments-crc
adoption=Manage
Ready=True
Reason=Reconciled

Argo:
sync=Synced
health=Healthy
revision=5549750fd010a1df2f14adfc6da49de799c882c2

Platform Operator:
CPU=1m
Memory=18Mi

CRC node:
CPU=2443m / 31%
Memory=22725Mi / 71%
```

## Allowed claim

`CONSUMER_1_CRC_RUNTIME_PROVEN`

This additionally promotes the Platform Operator from Kind-only proof to observed OpenShift/CRC consumer integration for this tested scope.

## Boundary

This does **not** prove:
- multi-node or HA behavior;
- worker/AZ/region/site failover;
- production sizing or throughput;
- production-grade identity, PKI or secret lifecycle;
- AKS/cloud runtime;
- production readiness.

CRC is a single-node engineering lab.
