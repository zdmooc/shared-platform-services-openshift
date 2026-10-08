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

Read-only ownership preflight (fails with code 40 before any drift, when initial ownership is healthy):

```bash
bash scripts/d093-op3-operator-argocd-day2.sh
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
