# D-093 / I6A — Production-style Operator Engineering

## Objective

Harden the existing `CapabilityConsumption` Platform Operator without changing its brownfield ownership model or introducing a destructive finalizer.

## Baseline reused

Already proven before I6A:

- Go / controller-runtime reconciliation;
- `CapabilityConsumption` CRD;
- Server-Side Apply with field manager `mayabank-platform-operator`;
- Observe / OwnershipConflict / explicit Manage;
- status, conditions and events;
- envtest;
- Kind runtime;
- OpenShift Local / CRC consumer #1 with SCC `restricted-v2`;
- Argo CD `Synced/Healthy`;
- Shared OIDC / Shared OTel;
- `deletionPolicy=Retain`.

## I6A changes

- Kubebuilder-style Makefile with `controller-gen` and `setup-envtest`;
- controller-gen generation gate in CI;
- CRD validation markers for namespace, resource profile and network profile;
- `Progressing` and `Degraded` conditions;
- deterministic partial-apply failure + idempotent recovery envtest;
- bounded Prometheus metrics:
  - `mayabank_platform_operator_reconcile_total`;
  - `mayabank_platform_operator_reconcile_duration_seconds`;
- Lease-based controller-runtime leader election;
- leader-election RBAC;
- Kind runtime proof for:
  - invalid CRD profile rejection;
  - two-replica Lease acquisition;
  - metrics endpoint;
  - existing reconciliation scenarios.

## Finalizer decision

No finalizer is added in I6A.

The V1 contract intentionally uses `deletionPolicy=Retain`. Deleting the intent object must not cascade-delete brownfield platform resources. A destructive finalizer would therefore add lifecycle coupling without a valid cleanup contract.

## Runtime evidence

Validated on branch `d093-i6a-operator-hardening`:

- final validated code head before documentation-only status sync: `ddbab78219a7c9537f5337e08f87d7b8098bc2bf`;
- Platform CI run `37587208717` — **SUCCESS**;
- D093 K3 Operator Kind Runtime run `37587208723` — **SUCCESS**;
- observed markers:
  - `I6A_LEADER_ELECTION_LEASE=PASS`;
  - `I6A_CRD_VALIDATION=PASS`;
  - `I6A_OPERATOR_METRICS=PASS`;
  - `K3_KIND_RUNTIME_RESULT=PASS`.

Allowed claim: `PLATFORM_CI_PROVEN + KIND_RUNTIME_PROVEN_I6A`.

Merged to `main` via PR #8 on squash commit `0d1d50ff52cfe1ee1734361db89837f34baec744`.

## Acceptance gates

- [x] `go mod tidy` clean;
- [x] `go fmt` clean;
- [x] `go vet ./...`;
- [x] envtest PASS;
- [x] controller-gen CRD/RBAC generation PASS;
- [x] generated RBAC contains Lease permissions;
- [x] generated CRD contains the I6A profile validations;
- [x] Kind runtime PASS with leader election + metrics + CRD negative test;
- [x] prior I4 reconciliation proof remains non-regressed.

## Truth boundary

I6A is Operator engineering hardening. It does not claim:
- production HA OpenShift;
- multi-node OpenShift;
- TradeOps consumer #2 Manage;
- OLM packaging;
- cloud runtime.

Those remain separate gates (I6B/I6C/K4/K5).

## Closure

I6A is **CLOSED / RUNTIME_PROVEN_WITHIN_KIND_SCOPE**. The evidence proves production-style Operator engineering mechanics on CI/envtest/Kind and preserves the earlier CRC/OpenShift consumer #1 proof. It does not claim OpenShift HA, production readiness, OLM packaging, or TradeOps Manage.
