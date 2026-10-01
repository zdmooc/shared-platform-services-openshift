# Shared Platform Services OpenShift

Plateforme technique commune MayaBank pour mutualiser les capacités transverses utilisées par les produits, plateformes Data/AI et POC OpenShift sans transformer les dépôts métier en plateformes techniques.

## Statut

**S0→S4 IMPLEMENTED IN REPOSITORY / RUNTIME EVIDENCE PENDING**

Le dépôt fournit les contrats, manifests, GitOps, observabilité, IAM/secrets patterns, qualité et CI nécessaires au socle commun. Une capacité n'est marquée `RUNTIME_PROVEN` qu'après exécution et collecte d'une preuve dans `evidence/`.

## Principes

- séparation stricte plateforme / produit ;
- aucune migration Big Bang ;
- nouveaux produits : `CONSUME_SHARED` par défaut pour les services transverses ;
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

## Itérations

- **S0** — Foundation, ownership model, namespaces, architecture, validation.
- **S1** — GitOps / Argo CD common control plane.
- **S2** — Observability: OpenTelemetry + Prometheus integration + Grafana assets.
- **S3** — IAM / OIDC + secrets integration contracts.
- **S4** — SonarQube integration, reusable CI/security gates and evidence model.

Voir [ROADMAP.md](ROADMAP.md), [architecture](docs/architecture/PLATFORM_ARCHITECTURE.md) et [runbook](docs/runbooks/BOOTSTRAP.md).

## Consommateurs

- `mayabank-instant-payments-resilience-platform`
- `mayabank-european-payment-processing-platform`
- `enterprise-data-lakehouse-kubernetes-openshift`
- `TradeOps-GenAI-Integration`
- `mayabank-ibm-mq-native-ha-openshift-eda-platform`

Chaque consommateur garde ses Deployments applicatifs, schémas, topics, SLO, tests et preuves runtime.
