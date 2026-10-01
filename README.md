# Shared Platform Services OpenShift

Plateforme technique commune MayaBank pour mutualiser les capacités transverses utilisées par les produits, plateformes Data/AI et POC OpenShift sans transformer les dépôts métier en plateformes techniques.

## Statut

**V1 / O3 COMPLETE — STATIC_VALIDATED + S5 KIND RUNTIME PROVEN + S6 CONTAINER SMOKE PROVEN + S7 CONSUMER CONTRACT VERIFIED / CRC PENDING**

Le dépôt fournit les contrats, manifests, GitOps, observabilité, IAM/secrets patterns, qualité et CI du socle commun.

Une capacité n'est promue qu'au niveau de preuve réellement observé.

## Preuves actuelles

- Platform CI : run 36860978223 — SUCCESS.
- S5 Kind runtime : run 36860978155 — SUCCESS.
- S5 chemin télémétrie : consumer → OTLP HTTP → OTel Collector → Prometheus exporter — PASS.
- S6 Keycloak OIDC + SonarQube : run 36840813149 — SUCCESS.
- S7 Instant Payments : STATIC_CONSUMER_CONTRACT_VERIFIED sur le commit consumer bc2ba297f0b2807c7168047e3c4ca4c674f942b5.
- CRC/OpenShift : PENDING / NOT_PROVEN.
- HA multi-nœud / production : NOT_CLAIMED.

## Principes

- séparation stricte plateforme / produit ;
- aucune migration Big Bang ;
- nouveaux produits : CONSUME_SHARED par défaut pour les services transverses ;
- composants dédiés autorisés lorsqu'ils sont l'objet du test ;
- rollback et reproductibilité obligatoires ;
- CRC mono-nœud = lab, jamais preuve HA production ;
- aucune topologie interne client n'est inférée.

## Modèle de responsabilité

| Capacité | Classification cible | Propriétaire |
|---|---|---|
| Argo CD / GitOps | CONSUME_SHARED | plateforme |
| Prometheus / Grafana | CONSUME_SHARED | plateforme |
| OpenTelemetry | CONSUME_SHARED | plateforme |
| Keycloak / OIDC | CONSUME_SHARED | plateforme |
| SonarQube / Quality Gates | CONSUME_SHARED | plateforme |
| secrets / PKI / Vault integration | CONSUME_SHARED | plateforme |
| Kafka métier | CONSUME_SHARED ou DEDICATED_FOR_TEST | selon scénario |
| PostgreSQL métier | CONSUME_SHARED ou DEDICATED_FOR_TEST | selon scénario |
| Angular / Spring Boot / Camel | PRODUCT_OWNED | produit |
| MongoDB read model métier | PRODUCT_OWNED | produit |

## V1 capabilities

- S0 — Foundation / governance.
- S1 — GitOps / Argo CD contracts.
- S2 — OpenTelemetry / Prometheus / Grafana contracts.
- S3 — IAM / OIDC / secrets contracts.
- S4 — SonarQube / reusable quality gates.
- S5 — Kind runtime portability and telemetry path.
- S6 — Keycloak OIDC + SonarQube live container smoke.
- S7 — Instant Payments consumer onboarding.
- S8 — hardening / rollback / evidence model.

## Runtime truth boundary

The Kind proof validates Kubernetes portability and the shared telemetry path.

The S6 proof validates container startup and integration endpoints for Keycloak and SonarQube.

The S7 verification validates repository contracts only.

None of those proves CRC/OpenShift, multi-node HA or production readiness.

## CRC/OpenShift next gate

Use docs/runbooks/CRC_RUNTIME_VALIDATION.md and scripts/runtime-smoke-openshift.sh.

Only an observed successful execution on CRC with archived evidence may promote the OpenShift column to CRC_RUNTIME_PROVEN.

## Consumers

- mayabank-instant-payments-resilience-platform
- mayabank-european-payment-processing-platform
- enterprise-data-lakehouse-kubernetes-openshift
- TradeOps-GenAI-Integration
- mayabank-ibm-mq-native-ha-openshift-eda-platform

Chaque consommateur garde ses Deployments applicatifs, schémas, topics, SLO, tests et preuves runtime.
