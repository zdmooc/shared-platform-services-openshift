# OpenShift / Kubernetes / CaaS / Platform Engineering / Day-2 / N3

**Zidane Djamal**  
**Architecte Solutions / Technique & Transverse**  
Dossier de démonstration technique - environnement bancaire / plateforme CaaS  
Date de preuve runtime : 08/10/2026

## 1. Objet

Ce dossier présente une démarche d'architecture et de diagnostic OpenShift orientée exploitation Day-2 et support N3. La preuve est réalisée sur OpenShift Local / CRC afin de démontrer les mécanismes OpenShift de manière reproductible.

La preuve CRC ne constitue ni une plateforme cible, ni une validation de haute disponibilité, ni une certification de production.

Le fil conducteur est :

ClusterVersion -> ClusterOperators -> Node / Capacity -> Projects / Namespaces -> Workloads -> Route / Router / Service / EndpointSlice / Pod -> SCC / RBAC / NetworkPolicy -> OLM -> GitOps -> Platform Engineering -> Storage -> Observability -> Day-2 / N3 / RCA -> Upgrade readiness / rollback.

## 2. Résultats de santé plateforme

- OpenShift : 4.22.7.
- ClusterVersion : Available=True, Progressing=False.
- ClusterOperators : tous Available=True, Progressing=False, Degraded=False au moment de la capture.
- Nœud CRC : Ready, rôles control-plane/master/worker, Kubernetes v1.35.6, RHCOS, CRI-O.
- CPU : 8 cores, 7.8 cores allocatables.
- Mémoire : 24 604 008 Ki capacity, 24 143 208 Ki allocatable.
- Node Conditions : MemoryPressure=False, DiskPressure=False, PIDPressure=False, Ready=True.

Point de capacité à surveiller : les requests observées atteignent environ 93 % du CPU allocatable et 98 % de la mémoire allocatable. Ce laboratoire est donc fonctionnel mais avec une marge de scheduling faible.

## 3. Architecture logique OpenShift

La lecture du cluster est structurée en quatre plans :

1. **Accès** : DNS, Route OpenShift, IngressController / Router.
2. **Plan de contrôle** : API server, etcd, scheduler, controllers, Cluster Version Operator et Cluster Operators.
3. **Plan d'exécution** : kubelet, CRI-O, RHCOS, OVN-Kubernetes, CSI.
4. **Plateforme applicative** : namespaces, Deployments, StatefulSets, Services, Operators, GitOps, observabilité et workloads.

Le laboratoire CRC regroupe control plane et worker sur un seul nœud. La transposition production doit séparer les rôles, les zones de panne et les responsabilités opérationnelles.

## 4. Réseau : Route vers Pod

La preuve de chemin applicatif est faite avec `mayabank-api/api-gateway`.

Chaîne observée :

Client -> Route `api-gateway` -> Router `default` -> Service `api-gateway` -> EndpointSlice -> Pod `api-gateway-bd554859d-nxbgq`.

La Route est `Admitted=True` et utilise une terminaison TLS `edge`.

Le Service est de type ClusterIP et expose le port proxy 8000.

L'EndpointSlice référence le Pod à l'adresse 10.217.0.95 avec `ready=true`, `serving=true`, `terminating=false`.

### Terminaisons TLS OpenShift

- **edge** : terminaison TLS sur le Router, backend potentiellement HTTP.
- **reencrypt** : terminaison TLS sur le Router puis nouvelle session TLS vers le backend.
- **passthrough** : le Router relaie le flux TLS ; le backend réalise la terminaison.

Exemples observés :
- API Gateway : edge.
- Console OpenShift : reencrypt.
- OAuth OpenShift : passthrough.

## 5. Sécurité et isolation

Le namespace `shared-platform-services` porte des métadonnées SCC OpenShift, une plage UID dédiée, des groupes supplémentaires et une posture Pod Security baseline.

Les contrôles à articuler pour un CaaS bancaire sont :

Namespace + ServiceAccount + RBAC + SCC + NetworkPolicy + ResourceQuota + LimitRange.

Le Platform Operator exécute ses conteneurs avec :
- runAsNonRoot=true ;
- allowPrivilegeEscalation=false ;
- drop ALL capabilities ;
- readOnlyRootFilesystem=true.

## 6. OLM

OLM est lu comme une chaîne de lifecycle :

CatalogSource -> Subscription -> InstallPlan -> CSV -> Operator -> CRD -> Custom Resource.

Le cluster contient Red Hat OpenShift GitOps 1.22.1 et Red Hat OpenShift Pipelines 1.23.2, avec des CSV en état Succeeded dans la capture.

OLM sain au niveau plateforme ne signifie pas qu'une Custom Resource métier ou plateforme est nécessairement Ready : le diagnostic doit descendre jusqu'aux CR et à leurs Conditions.

## 7. GitOps

Le namespace `openshift-gitops` contient les composants Argo CD : application controller, ApplicationSet controller, repo-server, server, Redis et Dex.

La démarche cible est :

Git -> Argo CD -> comparaison Desired / Live -> Sync -> ressources Kubernetes / OpenShift -> santé -> rollback Git.

Pour une plateforme CaaS, GitOps fournit la traçabilité de l'état désiré et réduit les opérations manuelles non reproductibles.

## 8. Platform Engineering

Le dépôt `shared-platform-services-openshift` porte un Operator de plateforme, exécuté dans le namespace `shared-platform-services`.

Le Deployment `mayabank-platform-operator` est disponible avec un replica Ready et sans restart au moment de la capture.

Le contrôleur observe la CRD `CapabilityConsumption` et plusieurs ressources Kubernetes : Namespace, ResourceQuota, LimitRange, ServiceAccount, Role, RoleBinding et NetworkPolicy.

Le modèle d'exploitation est :

Observe -> analyser l'existant -> détecter les conflits d'ownership -> Manage -> appliquer uniquement les ressources dont la plateforme est propriétaire -> vérifier Conditions et Events.

### Boucle de réconciliation

Custom Resource -> watch event -> reconcile -> lecture desired/live -> contrôle d'ownership -> Server-Side Apply -> Conditions / Events -> retry/backoff si erreur -> nouvelle réconciliation.

Deux cas Day-2 observés sont particulièrement utiles :

- `instant-payments-crc` : Ready=False avec ApplyFailed, lié à un webhook Tekton sans endpoint au moment de l'échec.
- `tradeops-crc` : Ready=False / AdoptionReady=False avec OwnershipConflict, car des baselines préexistantes sont déjà possédées par le produit.

Ces cas démontrent la différence entre un Operator qui tourne et une reconciliation métier réellement réussie.

## 9. Storage

La StorageClass par défaut du laboratoire est `crc-csi-hostpath-provisioner`, avec `WaitForFirstConsumer`.

Plusieurs PVC applicatifs sont Bound.

Ce stockage est adapté à un laboratoire CRC mais ne représente pas une stratégie de stockage de production bancaire. En cible, les sujets à cadrer sont : CSI supporté, classes de service, réplication, snapshot, chiffrement, RPO/RTO, reclaim policy, sauvegarde et restauration.

## 10. Observabilité

Le cluster expose les briques OpenShift Monitoring ainsi que ServiceMonitor, PodMonitor et PrometheusRule.

Mesure observée :
- CPU nœud : environ 42 %.
- Mémoire nœud : environ 86 %.

Le diagnostic doit distinguer :
- capacité et allocatable ;
- requests / limits ;
- consommation instantanée ;
- saturation réelle ;
- historique Prometheus et alertes.

## 11. Day-2 / N3 / RCA

La démarche RCA retenue est :

Symptôme -> impact -> état global -> scope opérateur -> namespace / workload -> events -> logs -> réseau / stockage / sécurité -> cause racine -> correction -> validation -> preuve -> prévention.

Les événements historiques observés fournissent plusieurs scénarios de diagnostic :
- erreurs Multus / création de Pod sandbox ;
- probes readiness ou liveness en échec ;
- Job BackoffLimitExceeded ;
- PDB sans Pods correspondants.

Un Warning historique n'est pas automatiquement un incident actif. Il faut toujours corréler timestamp, état courant, réplication du symptôme et santé des composants concernés.

## 12. Upgrade readiness

Le cluster est sur le channel `stable-4.22` et plusieurs mises à jour 4.22.x sont proposées.

Cependant la capture indique `Upgradeable=False` avec la raison `ClusterVersionOverridesSet`.

Le message explique que des overrides désactivant l'ownership empêchent les upgrades mineurs ou majeurs. Ce point doit être traité comme un gate de lifecycle, et non comme une simple anomalie cosmétique.

Le MachineConfigPool master est Updated=True, Updating=False, Degraded=False.

La démarche d'upgrade inclut : santé ClusterOperators, capacité, API dépréciées, OLM/CSV, StorageVersionMigration, MachineConfigPools, PDB, tests applicatifs, sauvegardes, fenêtre de changement et plan de retour.

## 13. Positionnement de la preuve

Ce laboratoire démontre :
- lecture top-down d'un cluster OpenShift ;
- diagnostic ClusterVersion / ClusterOperators ;
- capacité et scheduling ;
- réseau Route / Service / EndpointSlice / Pod ;
- SCC, RBAC, NetworkPolicy et isolation ;
- OLM et lifecycle Operators ;
- GitOps avec OpenShift GitOps ;
- Operator Platform Engineering et Conditions ;
- stockage, observabilité et RCA ;
- upgrade-readiness.

Il ne démontre pas :
- HA multi-control-plane ;
- perte de nœud réelle en production ;
- SLA / SLO de production ;
- PRA multi-site ;
- capacité à l'échelle d'un parc industriel.

## 14. Auteur

**Zidane Djamal**  
**Architecte Solutions / Technique & Transverse**

Approche : architecture, plateforme CaaS, sécurité, GitOps, automatisation, observabilité, exploitation Day-2, support N3 et analyse de causes racines.
