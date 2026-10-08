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
