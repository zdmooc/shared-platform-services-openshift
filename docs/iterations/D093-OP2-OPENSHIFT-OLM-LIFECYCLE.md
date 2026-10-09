# D-093 / OP2 — OpenShift OLM Lifecycle

Date: 2026-10-07  
Status: **IMPLEMENTED / CRC_RUNTIME_PENDING**

## Trigger

DAAROPS recruiter discussion emphasizes Kubernetes Operators. I6C already proves the OLM lifecycle on Kind; I5 separately proves the controller on CRC/OpenShift.

OP2 closes the exact evidence gap between those proofs.

## Deliverables

- `scripts/d093-op2-olm-crc.sh`;
- `docs/runbooks/DAAROPS_OLM_CRC_REPLAY.md`;
- manual GHCR publication workflow for Operator/bundle/catalog images;
- static OP2 CI gate.

## Safety

- dedicated OLM namespace;
- dedicated consumer namespace;
- direct Operator parked/restored automatically;
- test resources cleaned by default;
- no deletion of existing product consumers;
- fail closed before mutation if registry images are not pullable.

## Acceptance

Runtime closure requires all OP2 markers from the runbook.

## Current claim

**Not promoted yet.**

Current truth remains:

`KIND_OLM_LIFECYCLE_PROVEN + OPENSHIFT_OPERATOR_RUNTIME_PROVEN_CONSUMER_1`.

## Next

After runtime closure:

**OP3 — integrated Operator + Argo CD + Day-2 demonstration**.

## CRC read-only preflight — observed 2026-10-08

User-provided Git Bash output on `api.crc.testing:6443` / OpenShift Local 4.22.7:
- OLM Classic APIs detected: `OP2_OLM_CLASSIC_APIS=PASS`;
- the first GHCR check did **not** resolve `ghcr.io/zdmooc/mayabank-platform-operator:v0.1.0`;
- the reported failure means **missing or inaccessible with the current registry credentials**, not proven image non-existence;
- no OLM installation, direct-Operator scale-down, test namespace creation, or CRC lifecycle proof took place;
- `OPENSHIFT_OLM_LIFECYCLE_PROVEN_CRC` remains **not claimed**.

The manual publisher workflow exists in this **unmerged OP2 branch**, but not in `main`. GitHub `workflow_dispatch` requires the workflow file on the default branch; it cannot be assumed runnable before explicit integration. GHCR publication/visibility and any further CRC mutation require a separate controlled step. Do not bypass this by force-merging the PR.


## 2026-10-09 — OP3 SSA fix integration dependency before publishing

D-093/I1 technical OP3 PR #14 now contains code and envtests resolving
the already-managed quota's SSA `requests.storage` ownership conflict.
The I1 tested code head `b07cf830d8792c803a9ccf6849ffba1d4f31e3ee`
passed Platform CI, Operator Kind Runtime, and OP3 Static Gate. It has
**not yet been deployed to the user's CRC**.

**Release sequencing:** avoid publishing immutable GHCR `v0.2.0` tags from
an obsolete default-branch Operator binary while PR #14 remains unmerged.
Current publisher tags both Operator `v0.1.0` and `v0.2.0` from *one*
checkout, so the upgrade is a genuine **OLM packaging/CSV/catalog lifecycle**
exercise but **not** evidence that the Operator binary gained functionality
between tags. Preserve this distinction explicitly.

After user-authorized integration and review of the release commit:
1. pin image build commit SHAs and compare expected binary content;
2. verify GHCR publication + pull visibility for Operator v0.1/v0.2,
   bundle v0.1/v0.2 and catalog v0.2;
3. execute OP2 CRC preflight without mutation;
4. obtain separate approval for OP2 park/install/upgrade/recovery/uninstall;
5. only then claim `OP2_OPENSHIFT_OLM_LIFECYCLE_RESULT=PASS`.

**Do not merge or publish solely because the static gate is green.**


## OP2 final — CRC OLM lifecycle runtime PASS (2026-10-09)

User terminal evidence with the corrected OP2 script on OpenShift CRC 4.22.7:

- `OP2_OLM_CLASSIC_APIS=PASS`; `OP2_GHCR_IMAGES_PULLABLE=PASS`; `OP2_PREFLIGHT_READONLY=PASS`.
- Existing direct Operator replicas=1, parked: `OP2_DIRECT_OPERATOR_PARK=PASS`.
- OLM CatalogSource/OperatorGroup/Subscription/InstallPlan created. CSV v0.1.0 Succeeded; `OP2_OPENSHIFT_OLM_V010_INSTALL=PASS`.
- Dedicated `d093-op2-olm-consumer` Ready/Reconciled; quota storage 0/10Gi; `OP2_OPENSHIFT_OLM_CONSUMER_RECONCILE=PASS`.
- Upgraded OLM catalog/CSV v0.2.0 Succeeded; `OP2_OPENSHIFT_OLM_UPGRADE=PASS`.
- Quota deletion followed by automatic recreation; `OP2_OPENSHIFT_POST_UPGRADE_RECONCILIATION=PASS`.
- Subscription/CSV uninstalled; CRD, CR and quota observed retained **before** the script's explicit test cleanup; `OP2_OPENSHIFT_OLM_UNINSTALL_RETAIN=PASS`.
- Direct Operator restored to replicas=1 with successful rollout: `OP2_DIRECT_OPERATOR_RESTORE=PASS`.
- `OP2_OPENSHIFT_OLM_LIFECYCLE_RESULT=PASS`; `claim=OPENSHIFT_OLM_LIFECYCLE_PROVEN_CRC`.
- `truth_boundary=CRC_SINGLE_NODE_NOT_PRODUCTION_HA`.

**OP2 gate CLOSED / CRC_RUNTIME_PROVEN.** Earlier pending text in this document is historical.
Publisher GitHub Actions run `37900988346` was successful; GHCR images pullable.
v0.1 and v0.2 Operator images use the same build checkout: OLM packaging lifecycle is proven, not a functional binary upgrade.
The separate post-OLM check has since been supplied: see the final handoff section below.
Raw local log path: `/c/workspaces/d093-audit-readonly-20261008/op2-olm-final.log` (not imported).

## D-093 final post-OLM handoff — 2026-10-09

**D093_POST_OLM_HANDOFF_CHECK=PASS** from a separate user-executed,
read-only `oc` and `jq` validation after OP2 OLM lifecycle completion.

All assertions evaluated to `true` and the final explicit marker was observed:

- Direct Deployment `shared-platform-services/mayabank-platform-operator`: desired replicas 1, ready 1, available 1 and the manager image ending in immutable digest `sha256:acfa316265a0c3466a67dfecc1b731ae6a7bed78689dbe39a14bdad10d80d3a1`.
- `CapabilityConsumption/instant-payments-crc`: `Ready=True`, reason `Reconciled`.
- `instant-payments-local/ResourceQuota/platform-quota`: `spec.hard.requests.storage=20Gi`.
- `openshift-gitops/Application/instant-payments-tech-lead-shared-platform`: `Synced` and `Healthy`.
- Both OP2 test namespaces `d093-op2-olm` and `d093-op2-consumer` absent.
- Test `CapabilityConsumption/d093-op2-olm-consumer` absent.

**Closure verdict: D-093 CLOSED / CRC_SCOPE_RUNTIME_PROVEN.**
The OP1/OP4 prepared delivery and OP3 Operator/Argo self-heal, plus OP2
OLM install, upgrade, reconstruction, uninstall/Retain and original Operator
restoration are closed on the agreed CRC scope. No further cluster mutation
is required for D-093 closure. Future TradeOps `Manage` promotion remains
separately gated and is **not** authorized by this D-093 verdict.

Truth boundary: `CRC_SINGLE_NODE_NOT_PRODUCTION_HA`.
The OLM v0.1→v0.2 fixture is a package/CSV lifecycle, not a functional
Go controller migration. Full raw logs stay local unless separately added.
