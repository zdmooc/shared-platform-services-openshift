# D-093 / OP4 — Samir Operator-First Demo Pack

Date: 2026-10-07  
Status: **IMPLEMENTED / DEMO_PREPARED**

## Purpose

Turn the existing Operator engineering evidence and the OP1→OP3 execution lanes into one recruiter/client demonstration.

## Deliverables

- `docs/runbooks/DAAROPS_SAMIR_OPERATOR_DEMO_15MIN.md`;
- `scripts/d093-op4-samir-demo-preflight.sh`;
- static OP4 CI gate.

## Demo structure

1. platform problem / ownership;
2. CRD + Go Reconcile;
3. brownfield Observe -> Manage;
4. Argo CD vs Operator ownership;
5. Day-2 retry/failover;
6. OLM lifecycle;
7. real CRC/OpenShift consumer;
8. security/observability;
9. truth boundaries.

## Runtime rules

OP4 may reference existing I5/I6A/I6B/I6C evidence immediately.

It may only promote:
- `OPENSHIFT_OLM_LIFECYCLE_PROVEN_CRC` after OP2 live success;
- `OP3_OPERATOR_ARGO_DAY2_INTEGRATED_DEMO_PROVEN` after OP3 live success.

## Commercial boundary

The demo positions the user as:

**Architecte Technique OpenShift / Platform Engineer with demonstrable personal Go/Kubernetes Operator engineering**.

It does not invent professional Go tenure.
