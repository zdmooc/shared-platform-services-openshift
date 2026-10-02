# Shared Platform Services OpenShift

Plateforme technique commune MayaBank pour mutualiser les capacités transverses utilisées par les produits, plateformes Data/AI et POC OpenShift sans transformer les dépôts métier en plateformes techniques.

## Statut

**V1 / O3 COMPLETE — STATIC_VALIDATED + KIND RUNTIME PROVEN + CONTAINER SMOKE PROVEN + CONSUMER CONTRACTS VERIFIED + CRC SHARED OBSERVABILITY PROVEN**

Le dépôt fournit les contrats, manifests, GitOps, observabilité, IAM/secrets patterns, qualité et CI du socle commun.

Une capacité n'est promue qu'au niveau de preuve réellement observé.

## Preuves actuelles

- Platform CI : run 36860978223 — SUCCESS.
- S5 Kind runtime : run 36860978155 — SUCCESS.
- S5 chemin télémétrie : consumer → OTLP HTTP → OTel Collector → Prometheus exporter — PASS.
- S6 Keycloak OIDC + SonarQube : run 36840813149 — SUCCESS.
- Instant Payments : STATIC_CONSUMER_CONTRACT_VERIFIED sur le commit consumer bc2ba297f0b2807c7168047e3c4ca4c674f942b5.
- API Management : `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER` sur CRC 4.22.7 ; Shared OIDC → Kong → Payment API + traces vers Shared OTel observés.
- Customer/KYC : `STATIC_CONSUMER_CONTRACT_VERIFIED` avec profil Kustomize + contrat Argo CD ; runtime volontairement non revendiqué.
- CRC/OpenShift shared observability : CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY on OpenShift Local 4.22.7.
- Shared Identity CRC : `CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN` on OpenShift Local 4.22.7; RHBK runtime remains delegated to `keycloak-enterprise-roadmap-v7`.
- API Management shared runtime : `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`.
- HA multi-nœud / production : NOT_CLAIMED.

## Principes

- séparation stricte plateforme / produit ;
- aucune migration Big Bang ;
- nouveaux produits : CONSUME_SHARED par défaut pour les services transverses ;
- plateformes techniques spécialisées : consomment L2 et gardent leur runtime métier/technique spécifique ;
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
| API Management / Kong | SPECIALIZED_PLATFORM | API Management |
| IBM MQ | SPECIALIZED_PLATFORM | Messaging |
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
- S7 — first consumer onboarding.
- S8 — hardening / rollback / evidence model.

## Runtime truth boundary

The Kind proof validates Kubernetes portability and the shared telemetry path.

The S6 proof validates container startup and integration endpoints for Keycloak and SonarQube.

Consumer verification validates repository contracts only until a consumer actually resolves the shared capability at runtime.

None of those proves the whole platform on CRC/OpenShift, multi-node HA or production readiness.

## CRC/OpenShift evidence

Use docs/runbooks/CRC_RUNTIME_VALIDATION.md.

Recommended command:

```bash
bash scripts/run-crc-evidence.sh
```

The shared observability slice is now promoted to `CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY` based on the observed CRC 4.22.7 runtime. The next gate is API Management consuming shared OIDC and shared OTel on CRC.

## Consumers

- mayabank-instant-payments-resilience-platform
- mayabank-api-management-architecture
- mayabank-european-payment-processing-platform
- enterprise-data-lakehouse-kubernetes-openshift
- TradeOps-GenAI-Integration
- mayabank-ibm-mq-native-ha-openshift-eda-platform

Chaque consommateur garde ses Deployments applicatifs, schémas, topics, SLO, tests et preuves runtime.


## Shared Identity CRC next gate

The shared platform now provides `scripts/deploy-shared-identity-crc.sh` and `scripts/bootstrap-shared-identity-crc.sh`.

The deployment wrapper deliberately reuses the specialist repository `keycloak-enterprise-roadmap-v7` for the RHBK Operator, PostgreSQL lab runtime and Keycloak CR. This repository owns the shared `mayabank` realm/issuer contract and does not duplicate the specialist runtime.

Current claim: `CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN`.


## Consumer onboarding

Le runbook canonique est :
`docs/runbooks/CONSUMER_ONBOARDING.md`.

Consumers actuels :
- API Management — spécialisé, runtime CRC prouvé ;
- Customer/KYC/Digital — produit, contrat statique validé.
