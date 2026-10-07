# TradeOps consumer onboarding — D-090

**Consumer:** `zdmooc/TradeOps-GenAI-Integration`  
**Classification:** `PRODUCT_CONSUMER` / primary executable AI runtime  
**Status:** `D090_G1_G2_CRC_RUNTIME_PROVEN / D093_I6_OBSERVE_PREPARED`  
**Runtime promotion:** D-090 G1 and G2 are runtime-proven on CRC; D-093 consumer #2 now advances through brownfield `Observe` before any `Manage` handoff.

## Shared capabilities consumed

- identity / OIDC: `CONSUME_SHARED`;
- observability / OpenTelemetry: `CONSUME_SHARED`;
- secrets / PKI conventions: `CONSUME_SHARED`;
- GitOps conventions: `CONSUME_SHARED`;
- quality contracts: `CONSUME_SHARED`.

## Deliberately dedicated for the current lab

- Kafka/Redpanda runtime: `DEDICATED_FOR_TEST`;
- PostgreSQL workflow/audit runtime: `DEDICATED_FOR_TEST`;
- Qdrant RAG runtime: `DEDICATED_FOR_TEST`;
- LiteLLM AI routing lab: `DEDICATED_FOR_TEST` until G5.

## Product-owned

TradeOps owns:

- RAG and domain corpus;
- agents/workflows;
- MCP tools;
- deterministic Risk Gate;
- HITL workflow;
- paper/shadow trading semantics;
- application-specific AI prompts and business fallback.

## D-090 AI access contract

Target path:

```text
TradeOps
  -> Shared OIDC / client_credentials
  -> Kong AuthN/AuthZ
  -> server-side consumer mapping
  -> LiteLLM lab routing/policy
  -> approved model
  -> Shared OTel
```

Rules:

- no product-private Keycloak or OTel copy for this target profile;
- no authoritative consumer identity accepted from client headers;
- provider/LiteLLM secrets remain server-side;
- requested model aliases are constrained by gateway policy;
- standalone/mock mode remains available as `DEDICATED_FOR_TEST` and does not prove real model access.

## Evidence boundary

D-090 has now observed and closed:
- G1 full governed real-model path on CRC;
- G2 single-consumer live governance on CRC, including model denial, quota, budget, Shared OTel and shared OpenShift Prometheus/Thanos evidence.

Canonical TradeOps evidence:
- `evidence/d090/20261007-g1-crc-runtime-proof.md`;
- `evidence/d090/20261007-g2-crc-runtime-proof.md`.

The next platform-consumer proof is D-093 I6 consumer #2.

Brownfield sequence:

```text
Observe
 -> ownership inventory / zero namespace mutation
 -> refresh brownfield capacity + ownership map
 -> explicit approval
 -> Manage only if safe
```

The Observe CR is `consumers/tradeops/capability-consumption-crc-observe.yaml`.

Observe does **not** authorize:
- transfer of PostgreSQL, Redpanda/Kafka or Qdrant;
- transfer of TradeOps Deployments/StatefulSets/Services/Routes;
- deletion or replacement of product NetworkPolicies;
- `Manage`.

The provisional `ai-medium` profile in the Observe CR is intent only; Manage sizing must be refreshed from actual brownfield resource usage before approval.

G3/G4 later add ODM and cross-consumer isolation.

Reference: `cadrage_202682030` D-090 / AI Platform execution plan.
