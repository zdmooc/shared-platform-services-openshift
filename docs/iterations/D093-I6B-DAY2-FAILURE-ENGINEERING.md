# D-093 / I6B — Day-2 / Failure Engineering

## Objective

Prove that the Platform Operator does not merely expose failure state: transient failures must remain visible, preserve the root cause, trigger controller-runtime retry/backoff, and converge automatically after the dependency is repaired.

## Scope

I6B extends the I6A engineering baseline with Day-2 failure semantics:

- retryable apply failures return the root error after writing `Degraded=True`;
- dependency/read failures are surfaced as `DependencyReadFailed` and remain retryable;
- status-write failure cannot mask the underlying reconciliation error;
- bounded retryable-failure metrics expose failure stage without unbounded labels;
- Kind injects a real RBAC denial on Role creation;
- recovery is accepted only if the CR converges without any CR patch/update;
- leader pod loss must transfer the Lease to another replica;
- a managed resource deleted after leader loss must be reconstructed by the new leader.

## Failure contract

```text
transient dependency/apply failure
  -> Ready=False
  -> Degraded=True
  -> warning event
  -> root error returned
  -> controller-runtime rate-limited retry
  -> dependency repaired
  -> automatic reconcile
  -> Ready=True / Reconciled
  -> Degraded=False
```

Permanent user-intent errors such as invalid spec remain status-visible but are not deliberately converted into a retry storm.

## Runtime injection

The Kind proof temporarily removes only the `create` verb from the Operator ClusterRole rule for namespaced RBAC resources.

Expected sequence:

```text
CapabilityConsumption Manage
  -> Namespace created
  -> ServiceAccount created
  -> Role create denied
  -> ApplyFailed / Degraded
  -> RBAC create restored
  -> no CR mutation
  -> queued controller-runtime retry
  -> Role + remaining baseline converge
```

The test then deletes the current leader pod, waits for a different Lease holder, deletes the managed ResourceQuota, and requires the replacement leader to reconstruct it.

## Metrics

I6B adds:

`mayabank_platform_operator_retryable_failures_total{stage="<bounded-stage>"}`

Current bounded stages:

- `apply`;
- `dependency_read`;
- `reference`;
- `status_update`.

No namespace, consumer, error text, or other high-cardinality value is used as a metric label.

## Runtime evidence

Validated on branch `d093-i6b-day2-failure-engineering`:

- validated code head: `bc61413d304fb3fe9e08b9b6baf5d16d6c2f1f5b`;
- Platform CI run `37590043833` — **SUCCESS**;
- D093 K3 Operator Kind Runtime run `37590044290` — **SUCCESS**.

Runtime markers include:

- `I6B_TRANSIENT_APPLY_FAILURE_OBSERVED=PASS`;
- `I6B_AUTOMATIC_RETRY_RECOVERY=PASS`;
- `I6B_RETRYABLE_FAILURE_METRIC=PASS`;
- `I6B_LEADER_FAILOVER=PASS`;
- `I6B_POST_FAILOVER_RECONCILIATION=PASS`;
- `K3_KIND_RUNTIME_RESULT=PASS`.

Allowed claim: `PLATFORM_CI_PROVEN + KIND_RUNTIME_PROVEN_I6B_DAY2`.

Merged to `main` through PR #9 — squash commit `079b3f11a4b514e636b04bcaf97feabbc3fc66f0`.

## Acceptance gates

- [x] Go formatting/vet clean;
- [x] envtest partial-apply failure returns root error and recovers on retry;
- [x] envtest dependency-read failure exposes Degraded and recovers;
- [x] envtest joined error preserves both root apply failure and status-update failure;
- [x] Kind transient RBAC failure observed;
- [x] Kind automatic retry recovery without CR mutation;
- [x] retryable failure metric observed on leader;
- [x] leader Lease holder changes after leader pod deletion;
- [x] post-failover managed-resource reconstruction succeeds;
- [x] prior I6A/I4 runtime proof remains non-regressed.

## Truth boundary

This is a local Kubernetes/Kind Day-2 proof. It does not establish:

- OpenShift multi-node HA;
- production controller HA/SLO;
- OLM lifecycle;
- cloud runtime;
- TradeOps Manage;
- business-service OIDC/telemetry resilience beyond already existing product evidence.

## Closure

I6B is **CLOSED / KIND_RUNTIME_PROVEN_WITHIN_SCOPE**. I6C owns OLM/OpenShift packaging and lifecycle evidence.
