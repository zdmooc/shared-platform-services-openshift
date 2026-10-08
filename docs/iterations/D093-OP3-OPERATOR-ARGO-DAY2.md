# D-093 / OP3 — Operator + Argo CD + Day-2 Integrated Demo

Date: 2026-10-07  
Status: **IMPLEMENTED / CRC_RUNTIME_PENDING**

## Purpose

Prove the DAAROPS architecture as two bounded reconciliation domains:

- Argo CD owns product desired state;
- the Go Operator owns the platform baseline.

## Deliverables

- `scripts/d093-op3-operator-argocd-day2.sh`;
- `docs/runbooks/DAAROPS_OPERATOR_ARGO_DAY2_DEMO.md`;
- static CI gate.

## Runtime acceptance

A successful CRC run must emit:

`OP3_OPERATOR_ARGO_DAY2_INTEGRATED_DEMO_PROVEN=PASS`.

## Safety design

- product drift: replica change only;
- platform drift: quota is widened, never tightened;
- automatic rollback trap on failure;
- no product data/state deletion;
- no LLM/TradeOps dependency.

## Next

OP4 converts OP1/OP2/OP3 into the final 12–15 minute recruiter demo pack.

## CRC read-only preflight — observed 2026-10-08

User-provided Git Bash output on OpenShift Local 4.22.7:
- Argo CD `instant-payments-tech-lead-shared-platform`: `Synced / Healthy`;
- application workload `wero-ui`: desired/available replicas 1;
- `CapabilityConsumption/instant-payments-crc`: `Manage` but `Ready=False / ApplyFailed`;
- the Ready condition last transitioned on **2026-10-05T14:01:18Z**; its message identifies `namespace.operator.tekton.dev` failing to call `tekton-operator-proxy-webhook.openshift-pipelines.svc` because **no endpoints were available then**;
- because the status message predates the preflight, it does **not** establish that the webhook currently has no endpoints. A fresh read-only endpoint/Operator Deployment inventory is necessary.
- no product drift, quota drift or integrated runtime acceptance marker was produced.

The preflight now reports concise conditions and checks the Tekton service endpoints and direct Operator deployment without emitting full YAML or changing resources. Do not disable/delete Tekton webhooks or restart the cluster as a shortcut. Restore the external admission dependency only after verifying the current state and receiving authorization for the proposed fix.
