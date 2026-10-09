# DAAROPS OP4 — Samir Operator-First Demo Pack

Date: 2026-10-07  
Status: **IMPLEMENTED / DEMO PREPARED / LIVE OP2-OP3 EVIDENCE STILL GATED**

## Objective

Deliver one coherent 12–15 minute technical demonstration for the DAAROPS discussion with Samir.

The demo is intentionally centered on the topic emphasized during the phone exchange:

**Kubernetes Operators in Go on OpenShift, with GitOps/Argo CD, Day-2 and OLM around the Operator lifecycle.**

## Golden storyline

```text
Product team intent in Git
        |
        v
     Argo CD
        |
        +--------------------------> product workloads
        |
        +--> CapabilityConsumption CR
                    |
                    v
          Go / controller-runtime
             Platform Operator
                    |
          +---------+----------+
          |         |          |
        RBAC      Quota     NetworkPolicy
          |         |          |
          +---------+----------+
                    |
          Conditions / Events
          retry / backoff
          leader election
                    |
                    v
                   OLM
          install / upgrade / uninstall
```

## Before the call

Run the non-destructive preflight:

```bash
bash scripts/d093-op4-samir-demo-preflight.sh
```

Expected marker:

```text
OP4_DEMO_PREFLIGHT=PASS
```

If OP2 and OP3 have already been executed live, keep their evidence logs ready. If not, do **not** promote their runtime claims.

---

## 0:00–1:00 — Problem and architecture

Say:

> The problem is not how to deploy one YAML file. The problem is how a platform team offers self-service on existing OpenShift namespaces without silently taking ownership from product teams.

Show the architecture above.

Key message:

- Git remains the intent source;
- Argo CD owns product desired state;
- the Operator owns only the platform baseline;
- brownfield adoption is explicit.

---

## 1:00–3:00 — CRD and Go Reconcile

Open:

- `operators/platform-onboarding-operator/api/v1alpha1/capabilityconsumption_types.go`;
- `operators/platform-onboarding-operator/internal/controller/capabilityconsumption_controller.go`.

Show:

`CapabilityConsumption platform.mayabank.example/v1alpha1`.

Explain the Reconcile sequence:

```text
Get CR
 -> validate
 -> compute desired objects
 -> detect conflicts
 -> Observe OR Manage
 -> Server-Side Apply
 -> status / managedResources
 -> Ready=True / Reconciled
```

Points to verbalize:

- idempotent reconciliation;
- errors returned to controller-runtime;
- no custom fake retry loop;
- field manager `mayabank-platform-operator`;
- no forced ownership.

Fast command:

```bash
bash scripts/d093-op1-operator-interview-surface.sh
```

---

## 3:00–5:00 — Brownfield Observe -> Manage

Explain:

```text
Observe
 -> inventory
 -> OwnershipConflict if existing product baseline
 -> zero mutation
 -> explicit migration/adoption
 -> Manage
```

Use the Instant Payments proof:

```text
CapabilityConsumption/instant-payments-crc
adoptionPolicy=Manage
Ready=True
Reason=Reconciled
```

Explain why `deletionPolicy=Retain` exists.

Question to expect:

> Why no destructive finalizer?

Answer:

> V1 deliberately retains brownfield resources. A destructive finalizer would create lifecycle coupling that contradicts the Retain contract.

---

## 5:00–7:30 — Argo CD vs Operator

This is the central integration answer.

```text
Argo CD
 = product Git desired state
 = Deployments / Services / Routes / product config

Platform Operator
 = runtime platform control loop
 = RBAC / ResourceQuota / LimitRange / baseline NetworkPolicies
```

If OP3 has previously been runtime-proven on CRC, present its archived evidence (including the final Argo/Operator PASS markers). Do **not** silently rerun the mutating drift scenario during a 15-minute interview. Any fresh execution requires a reviewed maintenance window and explicit authorization:

```bash
# OPTIONAL, ONLY AFTER EXPLICIT AUTHORIZATION AND SAFETY REVIEW
CONFIRM_OP3_CRC_DRIFT=YES_I_AUTHORIZE_OP3_CONTROLLED_DRIFT bash scripts/d093-op3-operator-argocd-day2.sh
```

The proof deliberately demonstrates:

1. product Deployment drift -> Argo CD self-heal;
2. platform ResourceQuota drift -> Operator reconciliation;
3. final Argo `Synced/Healthy`;
4. final CapabilityConsumption `Ready=True/Reconciled`.

Key sentence:

> Argo CD and the Operator are complementary because the ownership boundaries are explicit and non-overlapping.

---

## 7:30–9:30 — Day-2 / failure engineering

Use I6B evidence.

Explain the already proven sequence:

```text
temporary RBAC apply failure
 -> Ready=False / ApplyFailed
 -> Degraded=True
 -> root error returned
 -> controller-runtime retry/backoff
 -> permission restored
 -> automatic convergence without CR change
```

Then:

```text
leader pod lost
 -> Lease holder changes
 -> second replica becomes leader
 -> reconciliation continues
 -> missing managed resource reconstructed
```

Do not claim multi-node OpenShift HA. This behavior was proven within the bounded Kind engineering scope.

---

## 9:30–11:30 — OLM lifecycle

Show:

- bundle v0.1.0;
- bundle v0.2.0;
- CSV;
- `replaces: mayabank-platform-operator.v0.1.0`;
- stable FBC catalog;
- OpenShift Classic and OLM v1 manifests.

Current baseline before OP2 live closure:

`KIND_OLM_LIFECYCLE_PROVEN + OPENSHIFT_OPERATOR_RUNTIME_PROVEN_CONSUMER_1`.

If OP2 has previously passed on CRC, show the archived evidence log and image/CSV provenance. **Do not rerun the full OLM lifecycle during the interview**: it can take longer than the allocated slot, parks the direct Operator, installs/uninstalls test resources, and requires explicit prior authorization. The replay entry point is documented for a separate controlled CRC window:

```bash
# OPTIONAL CONTROLLED REPLAY ONLY; NOT PART OF THE LIVE 2-MINUTE SECTION
CONFIRM_OP2_CRC_MUTATIONS=YES_I_AUTHORIZE_OP2_OPERATOR_PARK_AND_TEST_CLEANUP bash scripts/d093-op2-olm-crc.sh
```

Present only the markers actually recorded in CRC evidence:

```text
OP2_OPENSHIFT_OLM_V010_INSTALL=PASS
OP2_OPENSHIFT_OLM_UPGRADE=PASS
OP2_OPENSHIFT_POST_UPGRADE_RECONCILIATION=PASS
OP2_OPENSHIFT_OLM_UNINSTALL_RETAIN=PASS
OP2_OPENSHIFT_OLM_LIFECYCLE_RESULT=PASS
```

Only then use:

`OPENSHIFT_OLM_LIFECYCLE_PROVEN_CRC`.

---

## 11:30–13:00 — Real OpenShift consumer

Show the existing I5 proof:

- OpenShift Local / CRC 4.22.7;
- SCC `restricted-v2`;
- Instant Payments consumer #1;
- `Observe -> Manage`;
- platform quota/limits/RBAC/NetworkPolicies;
- Argo CD `Synced/Healthy`;
- Shared OIDC;
- Shared OTel;
- payment non-regression.

Key sentence:

> The Operator is not only tested against envtest/Kind; the controller has already reconciled a real brownfield payment consumer on OpenShift Local.

---

## 13:00–14:00 — Security and observability

Show quickly:

- SCC `restricted-v2`;
- non-root/read-only root filesystem;
- RBAC;
- NetworkPolicies;
- Events;
- Conditions;
- Prometheus reconcile/retry metrics;
- Shared OpenTelemetry integration.

Do not spend the demo on Grafana dashboards.

---

## 14:00–15:00 — Truth boundary and conclusion

Say explicitly:

> My professional background is architecture and OpenShift/platform work. The Go/controller-runtime Operator is a personal public technical portfolio that I can demonstrate in depth; I do not convert that into invented years of client Go development.

Then:

- CRC single-node != production HA;
- Kind != OpenShift production;
- OP2 is the exact OpenShift OLM lifecycle gate;
- product/application ownership remains with Git/Argo.

Final sentence:

> The important design point is the control model: declarative API, explicit ownership, safe brownfield adoption, continuous reconciliation, Day-2 recovery and lifecycle management through OLM.

---

## Interview questions to defend

### Why an Operator rather than only Helm or Kustomize?

Helm/Kustomize render desired manifests. The Operator provides a domain-specific runtime control loop with status, conditions, conflict detection, adoption semantics and continuous convergence.

### Why not manage everything with Argo CD?

Because product desired state and platform runtime policy are different ownership domains. Mixing them produces double ownership and unsafe brownfield takeover.

### How is idempotence achieved?

Desired platform objects are recomputed from the CR and applied through Server-Side Apply using a dedicated field manager. Repeated Reconcile executions converge to the same target.

### Why no ForceOwnership?

The platform targets brownfield namespaces. Silent field takeover would hide ownership conflicts instead of governing them.

### How does retry work?

A retryable failure is surfaced in status and the root error is returned to controller-runtime. The controller-runtime workqueue performs retry/backoff.

### What happens if the leader dies?

Another replica acquires the Lease and resumes reconciliation. I6B proved holder transfer and post-failover reconstruction within the Kind scope.

### What does OLM add?

Installation, versioned bundles/CSV, channels, upgrade graph and controlled Operator uninstall lifecycle.

### What is not proven?

Multi-node OpenShift HA, production SLOs and any runtime gate that has not actually been observed.

## Repository map for the call

Primary:

`zdmooc/shared-platform-services-openshift`

Supporting only:

- `argocd-expert-pack`;
- `mayabank-instant-payments-resilience-platform`;
- `openshift-platform-blueprints`.

Out of scope:

- TradeOps;
- LLM/LiteLLM/Ollama;
- RAG;
- ODM;
- MCP/IBM MQ.
