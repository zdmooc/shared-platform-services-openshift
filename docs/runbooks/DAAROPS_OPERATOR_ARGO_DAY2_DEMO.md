# DAAROPS OP3 — Operator + Argo CD + Day-2 Integrated Demo

Date: 2026-10-07  
Status: **IMPLEMENTED / CRC RUNTIME PENDING**

## Goal

Demonstrate the mission core as two complementary control loops rather than isolated tools.

```text
Product Git
   |
   v
Argo CD --------------------> product-owned Deployment
   |
   +--> CapabilityConsumption CR
              |
              v
       Go Platform Operator
              |
              +--> ResourceQuota
              +--> LimitRange
              +--> RBAC
              +--> NetworkPolicies
```

## Entry point

Read-only ownership and GitOps preflight (reports `OP3_PREFLIGHT_READONLY=PASS`; no drift injected):

```bash
OP3_PREFLIGHT_ONLY=true bash scripts/d093-op3-operator-argocd-day2.sh
```

Mutating drift rehearsal only after a separately approved CRC window:

```bash
CONFIRM_OP3_CRC_DRIFT=YES_I_AUTHORIZE_OP3_CONTROLLED_DRIFT \
  bash scripts/d093-op3-operator-argocd-day2.sh
```

The explicit opt-in prevents accidental changes to the product Deployment and platform quota.

Defaults reuse the already proven Instant Payments consumer:

- Argo namespace: `openshift-gitops`;
- Application: `instant-payments-tech-lead-shared-platform`;
- product namespace: `instant-payments-local`;
- CapabilityConsumption: `instant-payments-crc`;
- product Deployment: `wero-ui`;
- platform ResourceQuota: `platform-quota`.

All values are overridable through environment variables.


## Before Day-2: targeted recovery of stale consumer readiness

Observed on 2026-10-08: Tekton webhook endpoint recovered and is ready/serving;
the direct Go Operator Deployment is 1/1 ready (its **live** args are null, so
leader election is not enabled); `CapabilityConsumption/instant-payments-crc`
remains `Ready=False / ApplyFailed` with historical webhook message. The
previous user probes did not demonstrate a fresh successful reconcile.

A narrow, operator-triggered **requeue** is available as
`scripts/d093-op3-crc-reconcile-recovery.sh`. It does **not** restart any
components, touch TradeOps, change the CR spec, or directly patch any quota,
policy or product Deployment. The one write in `apply` mode is a **new annotation
on that exact existing CR**. Since adoptionPolicy is `Manage`, the controller
may then reapply its declared namespace metadata, quota, RBAC, limits and
NetworkPolicies; this write side effect is intentional and requires an approved
local CRC window.

Stage A (default, read-only):

```bash
D093_EVIDENCE_DIR=/c/workspaces/d093-op3-recovery-evidence \
  OP3_RECOVERY_MODE=readonly \
  bash scripts/d093-op3-crc-reconcile-recovery.sh
```

Stage B (separate, explicitly authorized mutation):

```bash
D093_EVIDENCE_DIR=/c/workspaces/d093-op3-recovery-evidence \
  OP3_RECOVERY_MODE=apply \
  CONFIRM_OP3_CRC_RECONCILE=YES_I_AUTHORIZE_INSTANT_PAYMENTS_PLATFORM_RECONCILE \
  OP3_RECOVERY_TIMEOUT_SECONDS=120 \
  bash scripts/d093-op3-crc-reconcile-recovery.sh
```

When retrieving the script from an unmerged PR without changing local branches,
run `git show origin/d093-op3-operator-argocd-day2-demo:scripts/d093-op3-crc-reconcile-recovery.sh`
and save its stdout to a standalone `.sh` file. The script does not depend
on repo-relative paths.

Expected successful result: `OP3_RECOVERY_RECONCILED=PASS` with status
`Ready=True / Reconciled`, managed `ResourceQuota` ownership and no
`Deployment` ownership. The script writes local JSON snapshots before and
after the targeted requeue. If it times out, preserve output and snapshots;
do **not** disable Tekton webhooks, edit consumer spec, restart operators or
retry unrestricted.

**Evidence boundary:** recovery only closes the consumer-readiness **prerequisite**.
The separately consented Day-2 Argo/Operator drift test below is still
required to claim `OP3_OPERATOR_ARGO_DAY2_INTEGRATED_DEMO_PROVEN=PASS`.

## What the live demo proves

### 1. Explicit ownership boundary

The script verifies:

- `CapabilityConsumption.status.managedResources` contains `ResourceQuota`;
- it does **not** contain `Deployment`;
- the Argo Application reports `Deployment/wero-ui` as a tracked resource.

This is the concrete answer to:

> Why use an Operator if Argo CD already exists?

Because they own different domains.

### 2. Product drift -> Argo CD

The script increases the desired replica count of `wero-ui` by one.

Expected behavior:

```text
manual product drift
 -> Argo OutOfSync or very fast heal
 -> self-heal
 -> replicas restored
 -> Application Synced/Healthy
```

### 3. Platform drift -> Go Operator

The script widens `ResourceQuota/platform-quota` `requests.storage` to `99Gi`.

This is intentionally non-blocking: it makes the quota less restrictive during the brief drift window.

Expected behavior:

```text
manual platform drift
 -> ResourceQuota watch
 -> CapabilityConsumption enqueue
 -> Reconcile
 -> Server-Side Apply
 -> original quota restored
 -> Ready=True / Reconciled
```

### 4. Final convergence

Both loops must finish healthy:

- Argo `Synced`;
- Argo `Healthy`;
- CapabilityConsumption `Ready=True / Reconciled`.

## Safety

- no StatefulSet, database, queue or payment data is deleted;
- product drift is replica-only and already proven safe in I35;
- quota drift widens a limit rather than tightening it;
- failure trap restores the original values if either controller does not converge;
- CRC single-node remains a lab, not HA/production evidence.

## Expected markers

```text
OP3_ARGO_INITIAL_SYNC=PASS
OP3_ARGO_INITIAL_HEALTH=PASS
OP3_OPERATOR_INITIAL_RECONCILED=PASS
OP3_OPERATOR_PLATFORM_OWNERSHIP=PASS
OP3_ARGO_PRODUCT_OWNERSHIP=PASS
OP3_OWNERSHIP_BOUNDARY=PASS
OP3_ARGO_PRODUCT_DRIFT_INJECTED=PASS
OP3_ARGO_SELF_HEAL=PASS
OP3_OPERATOR_PLATFORM_DRIFT_INJECTED=PASS
OP3_OPERATOR_DRIFT_RECOVERY=PASS
OP3_FINAL_ARGO_SYNC=PASS
OP3_FINAL_ARGO_HEALTH=PASS
OP3_FINAL_OPERATOR_RECONCILED=PASS
OP3_OPERATOR_ARGO_DAY2_INTEGRATED_DEMO_PROVEN=PASS
```

## Existing evidence reused

- D-093/I5: OpenShift Operator consumer #1;
- D-093/I6B: retry/failure/failover engineering;
- D-091/K1/I35: Argo CD drift/self-heal/prune/rollback on CRC.

OP3 does not repeat destructive prune/rollback demonstrations; it integrates the ownership story needed for the DAAROPS interview.


## Verified OP3 prerequisite — 2026-10-08

`instant-payments-crc` recovered under the consented single-annotation
requeue. Captured by user on CRC:
`OP3_RECOVERY_PREFLIGHT=PASS`,
`OP3_RECOVERY_ANNOTATION_APPLIED=PASS`,
`OP3_RECOVERY_RECONCILED=PASS`.
The recovery evidence is stored locally in
`/c/workspaces/d093-audit-readonly-20261008/recovery-evidence`.
Do not rerun the recovery script merely to regenerate the result.

This is a prerequisite only. Before demonstrating Day-2 drift, execute the
read-only `OP3_PREFLIGHT_ONLY=true` form above against the latest **PR #14**
script. Proceed to the mutating form only after fresh evidence and separate
explicit authorization. OP2's OLM CRC proof is independent and still pending.


## 2026-10-08 CRC partial failure — do not repeat drift until diagnosed

The user-run live test proved Argo product drift detection and self-heal but
**did not** prove Operator quota drift recovery. On timeout, the diagnostic
quota showed `requests.storage=99Gi` before the earlier script's silent EXIT
rollback. The quota's **current** value must be inspected read-only. This
version of the script checks whether any failure rollback actually restored
the quota, and differentiates **manual rollback** from **Operator self-heal**.

Before proceeding, retrieve:
1. exact live `resourcequota/platform-quota` requests.storage, ownership labels,
   managedFields manager entries for `f:requests.storage`;
2. direct Operator deployment logs (last 30 minutes);
3. `CapabilityConsumption/instant-payments-crc` Ready/Degraded conditions;
4. Argo application sync/health and `Deployment/wero-ui` desired/available
   replicas.

Hypothesis to test, not to assume: SSA conflict between `kubectl-patch`
field manager and Operator SSA field manager (`mayabank-platform-operator`)
can block quota self-heal without `ForceOwnership`. Only change the
reconciler or drift demonstration after concrete managed-field and error evidence.
