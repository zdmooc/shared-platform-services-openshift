# OpenShift / Kubernetes CaaS — Day-2 / N3 Demo Runbook

Purpose: read-only diagnostic and demonstration flow for an Expert Kubernetes / OpenShift / CaaS / Platform Engineering / Day-2 / N3 mission.

Environment used for the lab: OpenShift Local / CRC. This proves OpenShift-specific mechanisms and runtime behavior on a local single-node lab. It does **not** prove production HA.

All commands below are read-only. Commands such as `apply`, `patch`, `edit`, `delete`, `scale`, `rollout restart`, `rollout undo` and upgrade execution are intentionally excluded.

## 1. Context and global cluster health

```bash
oc whoami
oc whoami --show-server
oc get clusterversion version
oc get clusterversion version -o yaml
oc get clusteroperators
oc get nodes -o wide
oc get node crc -o custom-columns=NAME:.metadata.name,CPU_CAPACITY:.status.capacity.cpu,CPU_ALLOCATABLE:.status.allocatable.cpu,MEM_CAPACITY:.status.capacity.memory,MEM_ALLOCATABLE:.status.allocatable.memory,PODS_CAPACITY:.status.capacity.pods,PODS_ALLOCATABLE:.status.allocatable.pods
oc get node crc -o custom-columns=TYPE:.status.conditions[*].type,STATUS:.status.conditions[*].status
oc describe node crc
```

## 2. Projects, namespaces, quotas and limits

```bash
oc get projects
oc get namespace shared-platform-services -o yaml
oc get resourcequota -A
oc get limitrange -A
```

## 3. Workloads

```bash
oc get deployments,statefulsets,daemonsets,pods -A
oc get deployment,replicaset,pod -n shared-platform-services -o wide
oc describe deployment mayabank-platform-operator -n shared-platform-services
oc get events -n shared-platform-services --sort-by=.lastTimestamp
```

## 4. OpenShift network path

Target reasoning chain: Client -> Route -> Router / IngressController -> Service -> EndpointSlice -> Pod.

```bash
oc get routes -A
oc get route api-gateway -n mayabank-api -o yaml
oc get route console -n openshift-console -o yaml
oc get route oauth-openshift -n openshift-authentication -o yaml
oc get ingresscontroller -n openshift-ingress-operator
oc get pods -n openshift-ingress -o wide
oc get service api-gateway -n mayabank-api -o yaml
oc get endpointslices.discovery.k8s.io -n mayabank-api -l kubernetes.io/service-name=api-gateway -o yaml
oc get pods -n mayabank-api -o wide
oc get networkpolicy -A
```

TLS modes to explain during the demo:
- edge: TLS ends at the OpenShift router.
- reencrypt: TLS ends at the router, then a new TLS connection is opened to the backend.
- passthrough: the router forwards the encrypted flow and the backend terminates TLS.

## 5. Security: SCC, ServiceAccount, RBAC, NetworkPolicy

```bash
oc get scc
oc describe scc restricted-v2
oc get serviceaccount -n shared-platform-services
oc get deployment mayabank-platform-operator -n shared-platform-services -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
oc get role,rolebinding -n shared-platform-services
oc get clusterrole,clusterrolebinding | grep -i mayabank || true
oc auth can-i --list -n shared-platform-services --as=system:serviceaccount:shared-platform-services:mayabank-platform-operator
oc adm policy who-can use scc restricted-v2 -n shared-platform-services
oc get networkpolicy -n shared-platform-services -o yaml
oc get resourcequota,limitrange -n shared-platform-services -o yaml
```

## 6. OLM

Target reasoning chain: CatalogSource -> Subscription -> InstallPlan -> CSV -> Operator -> CRD -> Custom Resource.

```bash
oc get catalogsource -A
oc get subscriptions.operators.coreos.com -A
oc get installplans.operators.coreos.com -A
oc get clusterserviceversions.operators.coreos.com -A
oc get operators.operators.coreos.com -A
oc get crd
oc get crd | grep -Ei 'argoproj|tekton|platform|capability' || true
```

## 7. OpenShift GitOps / Argo CD

```bash
oc get pods -n openshift-gitops -o wide
oc get argocds.argoproj.io -A
oc get applications.argoproj.io -A
oc get appprojects.argoproj.io -A
oc get clusterserviceversions.operators.coreos.com -A | grep -Ei 'gitops|pipelines' || true
```

## 8. Platform Engineering

Focus: Observe -> Manage, reconcile loop, Server-Side Apply, ownership, Conditions / Events, retry / backoff and leader election.

```bash
oc get all -n shared-platform-services
oc get deployment mayabank-platform-operator -n shared-platform-services -o yaml
oc get deployment mayabank-platform-operator -n shared-platform-services -o yaml --show-managed-fields
oc logs deployment/mayabank-platform-operator -n shared-platform-services --tail=200
oc api-resources | grep -Ei 'platform|capability' || true
oc get capabilityconsumptions -A -o yaml 2>/dev/null || true
oc get platformapplications -A -o yaml 2>/dev/null || true
oc get lease -A | grep -Ei 'mayabank|platform' || true
oc get events -n shared-platform-services --sort-by=.lastTimestamp
```

## 9. Storage

```bash
oc get storageclass
oc get pvc -A
oc get pv
oc get volumeattachment -A
```

## 10. Observability

```bash
oc get pods -n openshift-monitoring -o wide
oc get servicemonitors.monitoring.coreos.com -A
oc get podmonitors.monitoring.coreos.com -A
oc get prometheusrules.monitoring.coreos.com -A
oc adm top nodes
oc adm top pods -A --sort-by=memory
```

## 11. Day-2 / N3 / RCA

```bash
oc get pods -A | grep -Ev 'Running|Completed' || true
oc get events -A --field-selector type=Warning --sort-by=.lastTimestamp
oc get events -A --sort-by=.lastTimestamp
```

## 12. Node lifecycle and Machine Config

```bash
oc get machineconfigpools
oc get machineconfigs
oc get kubeletconfigs
```

## 13. Upgrade readiness, migration and rollback history

```bash
oc get apirequestcounts.apiserver.openshift.io
oc get storageversionmigrations.migration.k8s.io -A
oc adm upgrade
oc rollout history deployment/mayabank-platform-operator -n shared-platform-services
oc rollout history deployment/api-gateway -n mayabank-api
oc get clusteroperator kube-storage-version-migrator
```

## Demo positioning

The core proof is OpenShift / Kubernetes CaaS, Platform Engineering, GitOps, security, observability, lifecycle and Day-2 / N3 RCA.

The Data Lakehouse or application stacks are workload proofs only. Kind multi-node demonstrates Kubernetes and workload behavior. CRC demonstrates OpenShift-specific mechanisms. CRC must never be presented as the client's target platform or as proof of production HA.


## Runtime evidence capture

The full read-only capture executed on 2026-10-08 is stored at:

`evidence/runtime/2026-10-08-openshift-caas-day2-n3-full-output.txt`

This evidence is produced on OpenShift Local / CRC and must be interpreted as lab evidence only, not as a production or HA certification.
