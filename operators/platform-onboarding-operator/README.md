# MayaBank Platform Onboarding Operator

Status: **K3 / I2-I5 RUNTIME PROVEN / I6A-I6C CLOSED — PLATFORM CI + KIND/OLM RUNTIME PROVEN / CRC CONSUMER #1 PROVEN**

This operator materializes D-093/K2. `CapabilityConsumption` is the canonical Kubernetes Platform API.

## Implemented

- Go/Kubebuilder-compatible project layout;
- `platform.mayabank.example/v1alpha1` CRD;
- status/conditions/events;
- `Observe` and `Manage` lifecycle;
- non-destructive ownership conflict reporting;
- Server-Side Apply field manager `mayabank-platform-operator`;
- label-based watches for continuous reconciliation without garbage-collection ownerReferences;
- platform-owned Namespace labels, RBAC, ResourceQuota, LimitRange and baseline NetworkPolicies;
- `Retain` deletion boundary;
- envtest scenarios for brownfield Observe, greenfield Manage/idempotence and overwrite refusal;
- I6A branch adds controller-gen/Makefile, CRD profile validation, Progressing/Degraded conditions, bounded Prometheus reconciliation metrics, Lease-based leader election and partial-apply recovery tests.

## DAAROPS OP1 — interview surface

The recruiter-driven OP1 gate makes the existing controller implementation easy to demonstrate without adding speculative features.

Use:

```bash
bash scripts/d093-op1-operator-interview-surface.sh
```

Runbook: `docs/runbooks/DAAROPS_OPERATOR_FIRST_DEMO.md`.

The script is read-only against an authenticated OpenShift cluster and falls back to source/evidence inspection when no live `oc` session is available.

## Brownfield rule

```text
Observe
 -> inventory / compare
 -> OwnershipConflict if product baseline still exists
 -> explicit migration in product Git
 -> Manage
 -> SSA without ForceOwnership
```

The operator does not deploy business workloads. Product Git + Argo CD retain Deployments, StatefulSets, Services, Routes, stateful dependencies and product-specific NetworkPolicies.

## I4 Kind runtime evidence

Main commit: `107ea4d7c651d12295a77d851ab8c2d6c8763fe8`.

Successful runs:
- Platform CI `37224601724` — SUCCESS;
- D093 K3 Operator Kind Runtime `37224601718` — SUCCESS.

Observed runtime markers include Manage, Server-Side Apply field ownership, profile update, drift recovery, controller restart, brownfield Observe/OwnershipConflict, explicit adoption and Retain deletion behavior.

Canonical evidence: `evidence/ci/D093-K3-operator-kind-runtime.md`.

Allowed claim: `KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR`.

## CRC/OpenShift evidence

I5 proved the Operator on OpenShift Local / CRC 4.22.7 with Instant Payments as consumer #1:
- SCC `restricted-v2`;
- Observe -> explicit Manage;
- platform-owned quota / LimitRange / RBAC / NetworkPolicies;
- zero-double-ownership handoff;
- Argo CD `Synced/Healthy`;
- Shared OIDC and Shared OTel revalidated;
- payment non-regression.

Allowed claim: `CONSUMER_1_CRC_RUNTIME_PROVEN`.

Canonical evidence: `evidence/runtime/D093-K3-I5-crc-consumer1-instant-payments-20261005.md`.

## Evidence boundary

Kind validates Kubernetes runtime behavior, I6A/I6B engineering/Day-2 mechanics and the I6C OLM lifecycle. CRC/OpenShift consumer #1 is separately runtime-proven by I5. Consumer #2, multi-node OpenShift HA, production readiness and cloud runtime remain unproven.


## Resource profiles

The Operator keeps generic and workload-class profiles separate.

- `small`: requests 2 CPU / 4Gi, limits 4 CPU / 8Gi, 4 PVC, 10Gi storage.
- `medium`: requests 4 CPU / 8Gi, limits 8 CPU / 16Gi, 6 PVC, 20Gi storage.
- `payments-medium`: requests 4 CPU / 8Gi, limits 12 CPU / 16Gi, 6 PVC, 20Gi storage.
- `ai-medium`: requests 6 CPU / 10Gi, limits 16 CPU / 24Gi, 8 PVC, 20Gi storage.

`payments-medium` was introduced during D-093/I5 after the Instant Payments CRC pre-Manage measurement showed 19 active pods with about 505m CPU requests, 3.2Gi memory requests, 9.15 CPU limits, 9.44Gi memory limits, four PVCs and 5Gi requested storage. The generic `medium` profile would have set `limits.cpu=8`, below existing declared usage, which could block a later pod replacement or rollout.

This profile change does not itself prove CRC Manage. Runtime promotion still requires the explicit Observe -> Manage handoff and post-handoff non-regression evidence.

## OLM / OpenShift packaging

I6C packages the controller as an OLM bundle with a stable FBC catalog. The current package is v0.2.0 and declares a packaging upgrade edge from the v0.1.0 lifecycle fixture. OpenShift installation contracts are provided for both OLM Classic and the OpenShift 4.22 OLM v1 extension APIs.

The automated Kind gate proves bundle install, upgrade, reconciliation continuity and non-destructive uninstall. OpenShift OLM lifecycle is not claimed until replayed on CRC/OpenShift; the existing I5 evidence remains the independent OpenShift controller-runtime proof.
