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

## Acceptance gates

- `go mod tidy` clean;
- `go fmt` clean;
- `go vet ./...`;
- envtest PASS;
- controller-gen CRD/RBAC generation PASS;
- generated RBAC contains Lease permissions;
- generated CRD contains the I6A profile validations;
- Kind runtime PASS with leader election + metrics + CRD negative test;
- prior I4 reconciliation proof remains non-regressed.

## Truth boundary

I6A is Operator engineering hardening. It does not claim:
- production HA OpenShift;
- multi-node OpenShift;
- TradeOps consumer #2 Manage;
- OLM packaging;
- cloud runtime.

Those remain separate gates (I6B/I6C/K4/K5).
