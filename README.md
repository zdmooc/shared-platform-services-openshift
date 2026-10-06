# Shared Platform Services OpenShift

Plateforme technique commune MayaBank pour mutualiser les capacités transverses utilisées par les produits, plateformes Data/AI et POC OpenShift sans transformer les dépôts métier en plateformes techniques.

## Statut

**V1 / O3 COMPLETE + D-093 K3/K4 I5 — PLATFORM OPERATOR KIND_RUNTIME_PROVEN + CONSUMER_1_CRC_RUNTIME_PROVEN + CRC SHARED OBSERVABILITY/IDENTITY PROVEN**

Le dépôt fournit les contrats, manifests, GitOps, observabilité, IAM/secrets patterns, qualité et CI du socle commun.

Une capacité n'est promue qu'au niveau de preuve réellement observé.

## Preuves actuelles

- Platform CI : run 36860978223 — SUCCESS.
- D-093 Platform Operator: Kind proof remains `KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR`; I5 additionally proves Instant Payments consumer #1 on OpenShift Local / CRC with explicit Observe -> Manage adoption, SCC `restricted-v2`, platform-owned quota/limits/RBAC/NetworkPolicies, zero-double-ownership handoff, Argo `Synced/Healthy`, Shared OIDC, Shared OTel trace and payment non-regression. Claim: `CONSUMER_1_CRC_RUNTIME_PROVEN`. Evidence: `evidence/runtime/D093-K3-I5-crc-consumer1-instant-payments-20261005.md`.
- S5 Kind runtime : run 36860978155 — SUCCESS.
- S5 chemin télémétrie : consumer → OTLP HTTP → OTel Collector → Prometheus exporter — PASS.
- S6 Keycloak OIDC + SonarQube : run 36840813149 — SUCCESS.
- Instant Payments : `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER` on the tested single-node CRC; Shared OIDC consumption, authenticated metrics access and a real `payment-orchestrator` trace exported to Shared OTel were observed on 2026-10-03. Canonical evidence: `mayabank-instant-payments-resilience-platform/docs/evidence/runtime/I33-I34-crc-shared-platform-tech-lead-20261003.md`.
- API Management : `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER` sur CRC 4.22.7 ; Shared OIDC → Kong → Payment API + traces vers Shared OTel observés.
- Customer/KYC : `STATIC_CONSUMER_CONTRACT_VERIFIED` avec profil Kustomize + contrat Argo CD ; runtime volontairement non revendiqué.
- CRC/OpenShift shared observability : CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY on OpenShift Local 4.22.7.
- Shared Identity CRC : `CRC_SHARED_IDENTITY_BOOTSTRAP_PROVEN` on OpenShift Local 4.22.7; RHBK runtime remains delegated to `keycloak-enterprise-roadmap-v7`.
- API Management shared runtime : `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`.
- HA multi-nœud / production : NOT_CLAIMED.

## D-098 — SQY Expert Kubernetes/OpenShift

For D-098, this repository is the **Platform Engineering proof owner**:
- Platform API / `CapabilityConsumption`;
- Operator / brownfield Observe -> Manage;
- shared OIDC / OTel contracts;
- platform-owned quota/RBAC/NetworkPolicy onboarding.

Mission pack:
- `docs/runbooks/D098_SQY_PLATFORM_RUNTIME_PACK.md`;
- `scripts/d098-sqy-readonly-evidence.sh`.

Existing D-093/I5 CRC evidence is reused; new runtime evidence is only captured for uncovered SQY-2/SQY-5 gaps.

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

The original S5 Kind proof validates Kubernetes portability and the shared telemetry path.

D-093/K3 I4 proves the `CapabilityConsumption` Platform Operator itself on Kubernetes 1.35 Kind: SSA field ownership, update, drift recovery, controller restart, brownfield conflict/adoption and Retain behavior.

D-093/K3-K4 I5 additionally proves a bounded OpenShift/CRC brownfield consumer integration with Instant Payments: Observe with zero mutation, explicit Manage adoption, SCC compatibility, measured quota profile, zero-window NetworkPolicy handoff, Argo product ownership, Shared OIDC/OTel and payment non-regression.

The S6 proof validates container startup and integration endpoints for Keycloak and SonarQube.

Consumer verification validates repository contracts only until a consumer actually resolves the shared capability at runtime.

None of those proves the whole platform on CRC/OpenShift, multi-node HA or production readiness.

## CRC/OpenShift evidence

Use docs/runbooks/CRC_RUNTIME_VALIDATION.md.

Recommended command:

```bash
bash scripts/run-crc-evidence.sh
```

The shared observability slice is `CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY` on CRC 4.22.7. Shared identity bootstrap is also proven. API Management and Instant Payments have both consumed shared OIDC + Shared OTel on CRC and are `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`. AKS promotion remains governed by D-086.

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
- Instant Payments — produit flagship, Shared OIDC + Shared OTel runtime CRC prouvé ;
- Customer/KYC/Digital — produit, contrat statique validé.
