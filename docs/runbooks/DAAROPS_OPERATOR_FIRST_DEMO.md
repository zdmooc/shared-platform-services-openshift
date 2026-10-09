# DAAROPS — Operator-First Interview Demo

Date: 2026-10-07  
Iteration: **OP1 — Operator interview hardening**  
Repository: `zdmooc/shared-platform-services-openshift`

## Objective

Make the existing Kubernetes Operator implementation immediately inspectable and defensible during a technical interview.

OP1 does **not** add artificial features. The controller already implements the required mechanics; this runbook exposes them in the order most useful for a recruiter/client discussion centered on Operators.

## Core storyline

```text
Git / Argo CD
     |
     v
CapabilityConsumption CRD
     |
     v
Go / controller-runtime Reconcile
     |
     +--> Observe / OwnershipConflict
     +--> explicit Manage
     +--> Server-Side Apply
     +--> Namespace / SA / RBAC
     +--> ResourceQuota / LimitRange
     +--> NetworkPolicies
     |
     +--> Conditions / Events / Metrics
     +--> retry / backoff
     +--> leader election / failover
```

Product workloads remain product-owned and Argo CD reconciled.

## 1. CRD and API contract

Show:

- `operators/platform-onboarding-operator/api/v1alpha1/capabilityconsumption_types.go`;
- `operators/platform-onboarding-operator/config/crd/bases/platform.mayabank.example_capabilityconsumptions.yaml`.

Key points:

- cluster-scoped CRD;
- `Observe` / `Manage`;
- `Retain` deletion policy;
- validated resource profiles;
- `status.conditions`;
- `status.managedResources`;
- print columns for Consumer / Environment / Namespace / Adoption / Ready.

Question to defend:

> Why a CRD instead of only Helm/Kustomize?

Answer: the CRD provides a domain-specific declarative API with observable status, runtime reconciliation and explicit brownfield ownership semantics.

## 2. Reconcile loop

Show:

`operators/platform-onboarding-operator/internal/controller/capabilityconsumption_controller.go`

Walk through this sequence:

```text
Get CapabilityConsumption
 -> validate target namespace
 -> compute desired platform-owned objects
 -> detect ownership conflicts
 -> Observe: status only, zero mutation
 -> Manage: set Progressing
 -> Server-Side Apply each object
 -> persist managed resource references
 -> Ready=True / Reconciled
```

Important implementation points:

- errors are returned to controller-runtime;
- retry/backoff is therefore real controller-runtime behavior;
- status write failures are also returned;
- no `ForceOwnership`;
- field manager = `mayabank-platform-operator`;
- `deletionPolicy=Retain` intentionally avoids a destructive finalizer.

## 3. Brownfield safety

Default path:

```text
Observe
 -> inventory / compare
 -> OwnershipConflict
 -> no mutation
 -> explicit product-side migration
 -> Manage
```

Explain that a pre-existing product-owned baseline is never silently taken over.

The exception for an existing Namespace in `Manage` is deliberately narrow: the Operator only adds its own labels after explicit adoption.

## 4. Continuous reconciliation

The controller watches both the CR and managed resource kinds:

- Namespace;
- ServiceAccount;
- ResourceQuota;
- LimitRange;
- Role;
- RoleBinding;
- NetworkPolicy.

Managed resources carry the `platform.mayabank.example/consumption` label and are mapped back to the owning `CapabilityConsumption`.

This is the basis for drift recovery without forcing Argo CD to own the same platform resources.

## 5. Conditions / Events

Conditions:

- `Ready`;
- `AdoptionReady`;
- `Progressing`;
- `Degraded`.

Typical states:

```text
Observe without conflict
Ready=False / ObserveMode
AdoptionReady=True

Ownership conflict
Ready=False / OwnershipConflict
AdoptionReady=False
Degraded=False / OwnershipProtected

Transient apply failure
Ready=False / ApplyFailed
Degraded=True

Successful Manage
Ready=True / Reconciled
AdoptionReady=True / Managed
Degraded=False
```

Events expose `OwnershipConflict`, `ObservationComplete`, `Reconciled` and retryable failures.

## 6. Server-Side Apply ownership

Show the `apply()` helper.

The Operator uses:

```text
FieldManager = mayabank-platform-operator
Server-Side Apply
ForceOwnership = false
```

Interview point:

> Argo CD and the Operator coexist because they do not own the same fields/resources by design.

## 7. Retry / backoff / failure engineering

I6B already proved:

- transient RBAC apply denial;
- `Ready=False / ApplyFailed`;
- `Degraded=True`;
- root error returned to controller-runtime;
- automatic retry/backoff;
- convergence after permission restoration without changing the CR.

Do not claim a custom backoff algorithm: controller-runtime owns the workqueue retry behavior.

## 8. Leader election

Show:

- `cmd/main.go`;
- Lease RBAC;
- two-replica deployment.

I6B already proved:

```text
leader pod deleted
 -> Lease holder changes
 -> second replica becomes leader
 -> reconciliation continues
 -> deleted managed resource reconstructed
```

## 9. Metrics

Key metrics:

- `mayabank_platform_operator_reconcile_total`;
- `mayabank_platform_operator_reconcile_duration_seconds`;
- `mayabank_platform_operator_retryable_failures_total{stage=...}`.

Labels remain bounded; namespace, consumer name and arbitrary error text are intentionally excluded.

## 10. OpenShift proof

Separate the claims:

- Kind = portable Kubernetes controller mechanics;
- CRC/OpenShift 4.22.7 = real controller execution with Instant Payments consumer #1;
- Kind + OLM = lifecycle mechanics;
- exact OLM lifecycle on CRC/OpenShift remains OP2.

Observed CRC proof includes:

- SCC `restricted-v2`;
- `Observe -> Manage`;
- ResourceQuota / LimitRange / RBAC / NetworkPolicies;
- Argo CD `Synced/Healthy`;
- Shared OIDC / Shared OTel;
- payment non-regression.

## 11. 30-second pitch

> I use a cluster-scoped CapabilityConsumption CRD as the platform API. A Go/controller-runtime Operator reconciles only platform-owned baseline resources. Brownfield starts in Observe, detects ownership conflicts without mutation, then moves explicitly to Manage. The controller uses Server-Side Apply without forced ownership, exposes Conditions, Events and bounded Prometheus metrics, returns transient failures to controller-runtime for retry/backoff, and runs with leader election. Product workloads stay owned by Git and Argo CD. The controller is proven on OpenShift Local with a real payment consumer, and its OLM lifecycle is already proven on Kind.

## 12. Truth boundaries

- personal Go/Operator portfolio != invented client Go tenure;
- CRC single-node != production HA;
- Kind OLM lifecycle != OpenShift OLM lifecycle;
- OP2 is dedicated to closing the exact OpenShift/CRC OLM lifecycle gap;
- TradeOps/LLM/ODM/MCP are outside this DAAROPS Operator demo.
