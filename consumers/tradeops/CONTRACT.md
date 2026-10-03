# TradeOps consumer onboarding — D-090

**Consumer:** `zdmooc/TradeOps-GenAI-Integration`  
**Classification:** `PRODUCT_CONSUMER` / primary executable AI runtime  
**Status:** `IMPLEMENTED / STATIC_CONSUMER_CONTRACT_PREPARED`  
**Runtime promotion:** pending observed D-090 G1/G2 evidence.

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

This contract does not claim a real model call or CRC deployment.

Promotion sequence:

```text
STATIC_CONSUMER_CONTRACT_PREPARED
 -> TESTED × SINGLE_CONSUMER
 -> DEPLOYED × SINGLE_CONSUMER
 -> VERIFIED × SINGLE_CONSUMER
```

G3/G4 later add ODM and cross-consumer isolation.

Reference: `cadrage_202682030` D-090 / AI Platform execution plan.
