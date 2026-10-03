# ODM AI consumer onboarding — D-090 G3/G4

**Consumer:** `zdmooc/mayabank-ibm-odm-ai-decision-architecture`  
**Classification:** `PRODUCT_CONSUMER` / decision architecture specialist  
**Status:** `IMPLEMENTED / STATIC_CONSUMER_CONTRACT_PREPARED`  
**Runtime promotion:** pending observed shared-gateway execution.

## Shared capabilities consumed

- identity / OIDC: `CONSUME_SHARED`;
- observability / OpenTelemetry: `CONSUME_SHARED`;
- secrets / PKI conventions: `CONSUME_SHARED`;
- GitOps conventions: `CONSUME_SHARED`;
- quality contracts: `CONSUME_SHARED`.

## D-090 workload identity

Target client identity: `odm-ai`.

Required scope: `ai.inference`.

Target audience: `ai-gateway`.

The gateway must derive the trusted consumer identity `odm` from the authenticated workload. The ODM client does not supply an authoritative consumer-id header and fails closed when the trusted response identity is not `odm`.

## AI capability consumed

During G3/G4 the AI Access capability is temporarily hosted by `TradeOps-GenAI-Integration`.

ODM consumes the `odm-extraction` model alias only.

The following remain product-owned:

- document extraction prompt/schema;
- confidence and provider-status gate;
- human-review fallback;
- deterministic ODM/business-policy boundary;
- audit semantics.

GenAI never owns the final insurance decision.

## Isolation contract

Expected negative tests:

```text
tradeops-ai -> odm-extraction      DENY
odm-ai      -> tradeops-default    DENY
wrong audience                     DENY
missing ai.inference scope         DENY
unknown client                     DENY
quota overflow                     DENY
```

## Evidence boundary

Static/unit evidence may prove contract shape and fail-closed behavior.

`VERIFIED × SHARED` requires observed successful calls from both TradeOps and ODM through the same deployed AI Access capability.

`VERIFIED × MULTI_TENANT_PROVEN` additionally requires observed cross-consumer isolation tests.
