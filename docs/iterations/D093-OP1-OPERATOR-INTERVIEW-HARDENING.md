# D-093 / OP1 — Operator Interview Hardening

Date: 2026-10-07  
Status: **IMPLEMENTED / CI PENDING**

## Purpose

The recruiter phone exchange identified Kubernetes Operators as the strongest DAAROPS technical focus.

OP1 does not add speculative controller features. It packages the already proven implementation into a reproducible interview surface.

## Deliverables

- `docs/runbooks/DAAROPS_OPERATOR_FIRST_DEMO.md`;
- `scripts/d093-op1-operator-interview-surface.sh`;
- `.github/workflows/d093-op1-operator-interview.yml`.

The surface exposes:

- CRD schema / validation / status;
- Reconcile flow;
- idempotence and continuous watches;
- brownfield Observe / OwnershipConflict / explicit Manage;
- Server-Side Apply without forced ownership;
- Conditions / Events;
- retry/backoff semantics;
- leader election;
- bounded Prometheus metrics;
- OLM packaging markers;
- optional read-only OpenShift evidence when an authenticated `oc` session is present.

## Acceptance gate

```text
OP1_OPERATOR_INTERVIEW_SURFACE_READY=PASS
```

CI must execute the script successfully from a clean checkout.

## Evidence reuse

OP1 reuses, rather than rebuilds:

- I6A production-style Go/Kubebuilder hardening;
- I6B Day-2 / failure engineering;
- I6C Kind OLM lifecycle;
- I5 OpenShift/CRC consumer #1.

## Next

OP2 closes the remaining lifecycle evidence gap:

```text
Kind OLM lifecycle proven
+
OpenShift controller runtime proven
        |
        v
OP2: exact OLM install/upgrade/uninstall replay on CRC/OpenShift
```

## Truth boundary

- OP1 is an interview/demo hardening gate, not a new production-runtime claim;
- OpenShift OLM lifecycle remains unproven until OP2 live evidence;
- CRC single-node is not production HA;
- TradeOps/LLM/ODM/MCP are outside OP1.
