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


## Integrated Day-2 CRC replay — PARTIAL FAILURE, 2026-10-08

User-run `TIMEOUT_SECONDS=180` with explicit OP3 drift authorization and latest script:
- `OP3_ARGO_INITIAL_SYNC/HEALTH=PASS`, `OP3_OPERATOR_INITIAL_RECONCILED=PASS`, ownership boundary PASS;
- baseline `wero-ui replicas=1 available=1 requests.storage=20Gi` confirmed;
- `OP3_ARGO_PRODUCT_DRIFT_INJECTED=PASS`;
- `OP3_ARGO_OUTOFSYNC_OBSERVED=PASS` and `OP3_ARGO_SELF_HEAL=PASS`: **Argo CD Day-2 self-heal runtime proof achieved**;
- `OP3_OPERATOR_PLATFORM_DRIFT_INJECTED=PASS`: quota was widened to `99Gi`;
- **FAIL**: `Operator did not restore ResourceQuota requests.storage (expected=20Gi current=99Gi)`. The diagnostics printed `99Gi` *before the EXIT trap attempted an unconditional/silent rollback*; the user log **does not prove the post-trap storage quota**.

Current truth:
- Argo drift/self-heal portion proven on CRC.
- Operator quota drift self-heal not proven; complete OP3 integrated runtime claim **PENDING**.
- Do **not** assume the quota remains at 99Gi; inspect the actual current quota.
- Potential reasons (not established without evidence): ResourceQuota watched-label mismatch, failed requeue, API admission or server-side apply managed-field ownership conflict after `oc patch`. Controller watches `ResourceQuota` and maps `platform.mayabank.example/consumption`; its SSA `ApplyOptions` lacks ForceOwnership. Logs, CR condition, ResourceQuota labels and managedFields are required before changing controller behavior.
- Do not rerun drift, restart Operator, modify TradeOps/PARK, or alter RBAC/webhooks.

The PR's EXIT recovery trap was corrected to **verify readback** and print
`OP3_QUOTA_ROLLBACK=PASS requests.storage=20Gi` with boundary
`MANUAL_ROLLBACK_NOT_OPERATOR_SELF_HEAL`, or
`OP3_ROLLBACK_ATTENTION_REQUIRED=YES` if restoration fails.
This fix is preventive for **future** runs, not retroactive proof of the already-run
CRC test. Added mocked regression covering successful and unsuccessful rollback.


## CRC 2026-10-09 follow-up — steady state RESTORED, drift mechanism still unproven

User-run read-only follow-up after unsuccessful OP3 Day-2 quota self-heal:
- live `instant-payments-local/ResourceQuota/platform-quota`: `spec.hard["requests.storage"]="20Gi"`, correct Operator managed-by/consumer/consumption labels;
- `CapabilityConsumption/instant-payments-crc`: `Ready=True, reason=Reconciled`, `observedGeneration=3, generation=3`; `Ready.lastTransitionTime=2026-10-08T21:04:48Z`;
- `Deployment/wero-ui`: desired/ready/available all 1;
- `ArgoCD Application/instant-payments-tech-lead-shared-platform`: `Synced/Healthy`;
- last 45m direct Operator logs emitted no entries;
- previous jq output `"managedFields":[]` is **not evidence of no managers**: `oc get ... -o json` suppresses managedFields by default. Re-run **read only** with `--show-managed-fields=true`, or via `oc get --raw /api/v1/namespaces/instant-payments-local/resourcequotas/platform-quota`.

**Interpretation:** no residual quota/product drift; manual EXIT-trap patch from earlier failed demo may have restored the 20Gi value, so return to nominal does **not** prove autonomous Operator drift recovery. Cause remains open between watched-resource enqueue behavior and SSA ownership conflict until managedFields and contemporaneous controller evidence obtained. Avoid a second drift injection, CR annotation requeue, or unapproved mutation.

**OP3 statuses:** `CRC_RECOVERY_PROVEN`, `CRC_READONLY_PREFLIGHT_PROVEN`, `ARGO_SELF_HEAL_CRC_PROVEN`, `OPERATOR_QUOTA_SELF_HEAL_CRC_PENDING`, `OP3_INTEGRATED_RUNTIME_PENDING`.

## 2026-10-09 — Quota SSA field ownership verified after failed OP3 drift

User-run `oc -n instant-payments-local get resourcequota platform-quota --show-managed-fields=true -o json` produced:
- `spec.hard.requests.storage=20Gi`, resourceVersion `8274441`;
- `mayabank-platform-operator` `operation=Apply`, `ownsStorage=true`, manager timestamp `2026-10-05T09:53:50Z`;
- `kubectl-patch` `operation=Update`, `ownsStorage=true`, manager timestamp `2026-10-08T21:04:48Z`;
- `kube-controller-manager` `operation=Update`, `ownsStorage=false`.

**Inference, not observed log:** competing/shared ownership of `f:requests.storage` strongly supports an SSA apply conflict during the 99Gi drift. The source `CapabilityConsumptionReconciler.apply()` sends `client.ApplyOptions{FieldManager: FieldManager}` without ForceOwnership; ordinary `oc patch` can claim/update that field. Kubernetes SSA rejects changing values owned by another manager unless conflict resolution is explicitly authorized. The current two managers claiming 20Gi do **not** prove the exact rejected request at the earlier time; operator error/metrics were not captured.

**Next gates:** (1) guarded controller/design correction for *already platform-managed* `ResourceQuota`, preserving existing adoption/ownership-conflict protections and testing SSA drift with a competing field manager; (2) rebuild/redeploy approved CRC operator and replay bounded OP3 drift to demonstrate auto-heal **without exit-trap manual rollback**; (3) OP2 publish accessible GHCR Operator/bundle images; (4) OP2 CRC OLM v0.1→v0.2 install/upgrade/recovery/uninstall with retention; (5) authorized technical PRs #11/#12/#14/#15 and governance PR #12 integration. No cluster mutation or GitHub merges authorized by this read-only inspection. D-093 remains PARTIALLY_CLOSED.


## D-093/I1 SSA Storage Drift Fix — committed, CI gate pending (2026-10-09)

Based on user CRC managedFields, both `mayabank-platform-operator` (Apply) and
`kubectl-patch` (Update) owned `f:requests.storage`. The initial
apply path used `client.ApplyOptions{FieldManager: FieldManager}` with no
force, explaining a plausible 409 SSA ownership conflict on `99Gi` drift.

Technical PR #14 now implements a **narrow conditional fallback**:
1. First call normal SSA Apply, never ForceOwner by default.
2. Only on a genuine Kubernetes `IsConflict` for the fixed
   `ResourceQuota/platform-quota`, re-read its labels and require
   `managed-by=mayabank-platform-operator` and the same non-empty
   `consumption` / `consumer` labels as the desired quota.
3. Require `requests.storage` to differ while **all other hard-limit keys
   and quantities remain identical**; otherwise return the original error,
   preserving protection for unrelated CPU/memory/PVC conflicts.
4. Retry SSA with `client.ForceOwnership` only for this already-owned
   quota; preserve both initial and fallback errors on failure.
5. Existing `detectConflicts` (unowned quota and another consumer) remains
   the primary non-destructive ownership guard.

New envtest regression scenarios:
- `TestManagedQuotaStorageConflictRecoversViaNarrowForce`: real apiserver
  creates 20Gi managed quota → competing `kubectl-patch` 99Gi → controller
  reconciles back to 20Gi and `Ready=True/Reconciled`.
- `TestManagedQuotaCPUConflictDoesNotForceOwnership`: CPU-only drift
  remains blocked.
- `TestManagedQuotaMixedStorageAndCPUDriftNeverForces`: mixed drift fails
  closed rather than taking CPU ownership.
- `TestUnownedQuotaStorageConflictRemainsProtected`: existing external
  quota retains its 99Gi and produces `OwnershipConflict`.

**Truth boundary:** code and tests in PR, not yet deployed or proven on CRC.
Do not repeat live quota drift until CI/envtest gates pass and the updated
Operator image is deployed through a separately approved, rollback-capable
CRC procedure. The existing direct CRC Operator image remains unchanged
until that operation.
