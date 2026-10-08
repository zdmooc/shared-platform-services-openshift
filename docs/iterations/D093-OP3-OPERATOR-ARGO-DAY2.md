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


## OP3 targeted-requeue recovery gate — prepared, CRC run outstanding

Following the user-read CRC inspections of 2026-10-08, Operator (one Ready
worker, live `args=null`) and Tekton proxy (`ready=true/serving=true`) are
available while `CapabilityConsumption/instant-payments-crc` remains
`Ready=False/ApplyFailed`. The prior Tekton error is historic; no live
admission request succeeded yet in the captured proof.

The OP3 PR adds `scripts/d093-op3-crc-reconcile-recovery.sh`, an explicit
`readonly` / `apply` gate with CRC-only API verification, consumer identity +
`Manage/Retain` checks, deployment readiness, Tekton endpoint readiness,
Argo Synced/Healthy, before/after snapshots, and **at most one** metadata
annotation of `instant-payments-crc` with a resource-version guard. It never
mutates Tekton/TradeOps or the product Deployment directly. The Operator's
Manage-mode reconcile **may write platform namespace/RBAC/quota/limits/policies**.

Mocked regression CI tests readonly, unavailable-webhook, wrong-cluster,
missing-consent and an authorized single-CR requeue. Do not promote runtime
status on CI alone. The user must execute the bounded apply script in the
local CRC and return evidence of `OP3_RECOVERY_RECONCILED=PASS`, then
OP3's **separate** Day-2 drift test is required before final closure.


## OP3 CRC consumer recovery — RUNTIME PROVEN, 2026-10-08

User-executed Git Bash, OpenShift Local CRC (previous context API `https://api.crc.testing:6443`), on existing direct Operator:
- `OP3_RECOVERY_PREFLIGHT=PASS` — prerequisite read-only gate;
- initial CR condition: `Ready=False / ApplyFailed` with previously observed Tekton webhook error;
- explicit `OP3_RECOVERY_MODE=apply` and `CONFIRM_OP3_CRC_RECONCILE=YES_I_AUTHORIZE_INSTANT_PAYMENTS_PLATFORM_RECONCILE`;
- `OP3_RECOVERY_MUTATION_SCOPE=CapabilityConsumption/instant-payments-crc metadata.annotation only`;
- `OP3_RECOVERY_ANNOTATION_APPLIED=PASS`;
- `OP3_RECOVERY_RECONCILED=PASS`;
- `OP3_RECOVERY_SCOPE=CRC_CONSUMER1_ONLY`;
- `truth_boundary=RECONCILIATION_RECOVERY_NOT_OP3_DAY2_DRIFT_PROOF`.

The recovery script's success predicate checked generation/status convergence,
`Ready=True / Reconciled`, at least one managed `ResourceQuota`, and no
`Deployment` ownership. Local evidence directory reported:
`/c/workspaces/d093-audit-readonly-20261008/recovery-evidence`
with JSON before/after snapshots; these files remain on the user's PC
and are **not** uploaded to GitHub by this operation.

**Closed gate:** OP3 consumer-readiness recovery on CRC, not the complete OP3
Argo/Operator Day-2 drift proof. No D-093/OP3 full `CRC_RUNTIME_PROVEN` promotion
yet. Next: run `OP3_PREFLIGHT_ONLY=true` on the current PR branch script, then
separately authorize the controlled integrated drift rehearsal if the preflight
passes.


## OP3 integrated Day-2 read-only prerequisite — PASS on CRC, 2026-10-08

User-executed `TIMEOUT_SECONDS=45 OP3_PREFLIGHT_ONLY=true` on
`api.crc.testing:6443`, OpenShift 4.22.7, after successful consumer recovery.
Actual terminal markers:
- `OP3_ARGO_INITIAL_SYNC=PASS`
- `OP3_ARGO_INITIAL_HEALTH=PASS`
- `OP3_OPERATOR_INITIAL_RECONCILED=PASS`
- `OP3_OPERATOR_PLATFORM_OWNERSHIP=PASS`
- `OP3_ARGO_PRODUCT_OWNERSHIP=PASS`
- `OP3_OWNERSHIP_BOUNDARY=PASS`
- `OP3_PREFLIGHT_READONLY=PASS`.

Platform-owned kinds observed: `LimitRange`, `Namespace`, `NetworkPolicy`,
`ResourceQuota`, `Role`, `RoleBinding`, `ServiceAccount`.
Argo owns `Deployment/wero-ui`. Neither quota nor Deployment was changed.

**Gate closed:** OP3 preflight and ownership boundary on CRC. **Still pending:**
separately consented live replica drift/self-heal, platform quota drift/recovery,
and final integrated proof marker. The scoped mutating script now checks
`wero-ui` desired/available replicas are exactly `1/1` and
`ResourceQuota/platform-quota requests.storage=20Gi` before its first write.
A changed CRC baseline fails closed. These checks do not alter the read-only
preflight result above.
