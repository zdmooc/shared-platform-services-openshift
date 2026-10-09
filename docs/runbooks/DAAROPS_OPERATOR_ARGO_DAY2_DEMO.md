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


## D-093/I2 — Delivering the corrected Operator on CRC (not yet executed)

The D-093/I1 controller change **already passed GitHub Platform CI,
K3 Operator Kind Runtime, and OP3 static gate** on the tested code commit
`b07cf830d8792c803a9ccf6849ffba1d4f31e3ee`.
The source is on technical PR #14; it has **not** replaced the live CRC
image, which user evidence showed as the OpenShift internal-registry digest
`sha256:ee3c1caed1d27642f11e7491a0e46442a08b0b6cb84df4258c4b7f52a8798d73`.

### Stage 1 — inspect the live packaging, read-only

From Git Bash on the user's own CRC machine (with `main` left untouched):

```bash
cd /c/workspaces/shared-platform-services-openshift
git fetch origin
AUDIT_DIR="/c/workspaces/d093-audit-readonly-20261008"
mkdir -p "$AUDIT_DIR"
git show origin/d093-op3-operator-argocd-day2-demo:scripts/d093-op3-crc-rollout-inventory.sh \
  > "$AUDIT_DIR/op3-rollout-inventory.sh"
bash -n "$AUDIT_DIR/op3-rollout-inventory.sh"
set -o pipefail
bash "$AUDIT_DIR/op3-rollout-inventory.sh" 2>&1 \
  | tee "$AUDIT_DIR/op3-rollout-inventory.log"
```

This inventory checks the actual Operator Deployment/ServiceAccount/image,
ImageStream, BuildConfigs, Pod, consumer condition, quota baseline, application
replicas and Argo state; it does not mutate the cluster.

### Stage 2 — approval-gated build/rollout (PENDING)

After inventory reveals the actual build source and image pipeline:
1. Pin the **PR #14 commit SHA** to avoid a moving branch; separately
   preserve current Operator `Deployment` YAML, digest and rollback revision.
2. Prepare a uniquely tagged replacement image from the validated
   commit, not an overwrite of `:dev` or an existing digest.
3. Verify image is accessible to the `shared-platform-services` service
   account and that the replacement uses the same RBAC, CPU/RAM resources,
   probes and SCC. Do not alter the CRD/consumer or product namespace.
4. **Only after explicit CRC approval**, update the Operator's image via
   the existing observed image-build path, wait for a healthy deployment
   and revalidate `Ready=True / Reconciled`, quota 20Gi and Argo
   `Synced / Healthy`.
5. If the rollout fails, restore the pinned old digest and verify health;
   report rollback evidence rather than silently continuing.

Do not construct a guessed registry push/BuildConfig or use `oc rollout restart`
until the live inventory confirms deployment provenance. Do not merge any PR
or tag/publish GHCR merely for this I2 validation.

### Stage 3 — controlled end-to-end proof (PENDING)

The previous run proves Argo self-heal but **not** the Operator quota repair.
Once a patched image is running, run the latest OP3 read-only preflight.
A separately authorized bounded Day-2 run must show actual 99Gi→20Gi
reconciliation before trap/manual rollback; final marker
`OP3_OPERATOR_ARGO_DAY2_INTEGRATED_DEMO_PROVEN=PASS`.
Inspect post-run managedFields and `Ready` conditions to distinguish
controller self-heal from script rollback. Keep the historical result
`PARTIAL` until new CRC evidence arrives.


### I2 inventory observed 2026-10-09 — internal registry, no BuildConfig

User's `OP3_ROLLOUT_INVENTORY_READONLY=PASS` on CRC:
- direct Deployment `shared-platform-services/mayabank-platform-operator`
  `1/1` Available, `manager`, `serviceAccount=mayabank-platform-operator`,
  `strategy=RollingUpdate`, `args=null`, `imagePullPolicy=IfNotPresent`;
- pinned old image `image-registry.openshift-image-registry.svc:5000/shared-platform-services/mayabank-platform-operator@sha256:ee3c1caed1d27642f11e7491a0e46442a08b0b6cb84df4258c4b7f52a8798d73`;
- ImageStream `mayabank-platform-operator` contains existing tags
  `crc-i5`, `crc-i5-handoff`, `crc-i5-payments-medium`;
- **no BuildConfig is present**, so do not assume an existing build pipeline;
- current target consumer `Ready=True/Reconciled`, quota `20Gi`,
  product `wero-ui=1/1`, Argo `Synced/Healthy`.

### I2 Stage 2 — separate, consented binary build (NO Deployment change)

The OP3 branch contains
`scripts/d093-op3-crc-operator-binary-build.sh`.
It defaults to **read-only** and pins the Platform-CI/Kind-tested source commit
`91e99136add2f3af6ee3c03373445abc93d23654`.
It refuses any changed CRC API, old digest, consumer readiness, quota or
Argo status, any pre-existing dedicated BuildConfig or new target tag.
It archives only `operators/platform-onboarding-operator` from that
exact commit (no modification of local `main`) and, with explicit consent,
creates a **dedicated binary Docker BuildConfig** and runs an OpenShift
binary build to the new tag
`mayabank-platform-operator:crc-i2-ssa-91e99136add2`.
It does **not** change the Operator Deployment or overwrite any `crc-i5*`
tag. A failed build leaves its BuildConfig/Build evidence for investigation;
do not silently retry or clean up.

User Git Bash:

```bash
cd /c/workspaces/shared-platform-services-openshift
git fetch origin
AUDIT_DIR=/c/workspaces/d093-audit-readonly-20261008
mkdir -p "$AUDIT_DIR"
git show origin/d093-op3-operator-argocd-day2-demo:scripts/d093-op3-crc-operator-binary-build.sh > "$AUDIT_DIR/op3-i2-build.sh"
bash -n "$AUDIT_DIR/op3-i2-build.sh"
set -o pipefail

# Stage 2A: read-only. Expected OP3_I2_BUILD_READONLY=PASS
OP3_I2_MODE=readonly bash "$AUDIT_DIR/op3-i2-build.sh" \
  2>&1 | tee "$AUDIT_DIR/op3-i2-build-readonly.log"

# Stage 2B: build-only, separate authorization, NO deployment.
OP3_I2_MODE=build \
CONFIRM_OP3_I2_BINARY_BUILD=YES_I_AUTHORIZE_CRC_BUILD_NO_DEPLOY \
bash "$AUDIT_DIR/op3-i2-build.sh" \
  2>&1 | tee "$AUDIT_DIR/op3-i2-build-active.log"
```

Expected result before any rollout:
`OP3_I2_BINARY_IMAGE_BUILT=PASS` and a real pinned
`OP3_I2_NEW_IMAGE_DIGEST=...@sha256:...`.
The build requires the OpenShift builder service account and working access
to its Dockerfile bases/dependencies (Go 1.25); a preflight cannot
guarantee success. **Do not deploy the new image or repeat OP3 drift
before reviewing the actual build result and separately approving rollout.**
