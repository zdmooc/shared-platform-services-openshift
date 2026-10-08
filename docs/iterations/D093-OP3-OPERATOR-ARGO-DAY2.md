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
- the Ready condition last transitioned on **2026-10-05T14:01:18Z**; its message identifies `namespace.operator.tekton.dev` failing to call `tekton-operator-proxy-webhook.openshift-pipelines.svc` because **no endpoints were available when that failure occurred**;
- the condition has `lastTransitionTime=2026-10-05`, but that is the *last status transition*, not necessarily the most recent failed reconcile; an unchanged `Ready=False` may retain that timestamp while retries occur.
- no product drift, quota drift or integrated runtime acceptance marker was produced.

The preflight now reports concise conditions and checks the Tekton service endpoints and direct Operator deployment without emitting full YAML or changing resources. Do not disable/delete Tekton webhooks or restart the cluster as a shortcut. Restore the external admission dependency only after verifying the current state and receiving authorization for the proposed fix.


## CRC follow-up — same-day read-only inventory (2026-10-08)

Second user-run command output establishes:
- `shared-platform-services/mayabank-platform-operator`: Deployment 1/1 Available, pod 1/1 Running;
- `openshift-pipelines/tekton-operator-proxy-webhook`: Deployment 1/1 Available; Service 443/TCP; Endpoints `10.217.0.82:8443`; matching EndpointSlice exists;
- all 17 listed `openshift-pipelines` Deployments are 1/1 available;
- `CapabilityConsumption/instant-payments-crc`: observedGeneration=3, generation=3, still `Ready=False / ApplyFailed`, carrying its earlier webhook error.

**Claim boundary:** ready Tekton proxy pod and current service endpoint disprove a *currently missing-endpoints* hypothesis, but do **not** prove admission request success or tell whether the Operator retried after recovery. Kubernetes `meta.SetStatusCondition` retains `lastTransitionTime` when the condition status is unchanged; inspect recent Operator logs/events to distinguish active admission failure versus unreconciled state. Controller source returns the apply error (automatic controller-runtime rate-limited retry). No restart, update, or drift authorized/performed.

**Next:** read-only inspection of last 60 minutes of direct Operator logs and per-CR events plus EndpointSlice readiness; only after results decide whether to request explicit approval for a targeted requeue/metadata trigger. OP3 `CRC_RUNTIME_PENDING` unchanged.
