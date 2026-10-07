# D-093 / I6C — OLM / OpenShift Operator Packaging

## Objective

Package the existing Platform Operator as a lifecycle-managed Operator without changing the brownfield ownership contract.

## Packaging

Current package version: `0.2.0`.

Artifacts:

- previous lifecycle fixture: `bundle-v0.1.0/`;
- current bundle: `bundle/`;
- current CSV: `mayabank-platform-operator.v0.2.0`;
- upgrade edge: `v0.2.0 replaces v0.1.0`;
- channel: `stable`;
- file-based catalog: `catalog/mayabank-platform-operator/catalog.yaml`;
- bundle images: `bundle-v0.1.0.Dockerfile`, `bundle.Dockerfile`;
- catalog image: `catalog.Dockerfile`.

The v0.1.0 -> v0.2.0 pair is a **lifecycle packaging fixture**. Both versions use the same current controller code during the local proof. It demonstrates OLM install/upgrade orchestration, not a functional controller-code migration.

## OpenShift surfaces

### OLM Classic

`config/olm/openshift-classic/` provides:

```text
CatalogSource
  -> Subscription
  -> InstallPlan
  -> ClusterServiceVersion
  -> two-replica leader-elected Operator
```

### OLM v1 / OpenShift 4.22

`config/olm/openshift-v1/` provides:

```text
ClusterCatalog
  -> ClusterExtension
```

The installer ServiceAccount is intentionally not bound to cluster-admin in Git. Installation RBAC remains an environment-governance decision.

## Kind OLM lifecycle proof

The automated gate executes:

```text
Kind
  -> Operator SDK OLM install
  -> bundle v0.1.0 install
  -> CSV Succeeded
  -> CapabilityConsumption Manage / Reconciled
  -> bundle-upgrade v0.2.0
  -> CSV v0.2.0 Succeeded
  -> post-upgrade resource reconstruction
  -> delete Subscription + current CSV
  -> Operator Deployment removed
  -> CRD retained
  -> CR retained
  -> managed Namespace/ResourceQuota retained
```

This validates the intended `Retain` uninstall boundary.

## Version baseline

- Operator SDK: `v1.42.3`;
- operator-registry / opm image: `v1.74.0`;
- Kubernetes Kind node: `v1.35.8`.

## Acceptance gates

- [ ] bundle v0.1.0 passes `operator-sdk bundle validate`;
- [ ] bundle v0.2.0 passes `operator-sdk bundle validate`;
- [ ] FBC passes `opm validate`;
- [ ] bundle and catalog images build;
- [ ] existing Go/envtest/I6B tests remain green;
- [ ] OLM installs on Kind;
- [ ] v0.1.0 CSV reaches Succeeded;
- [ ] Operator reconciles a real CapabilityConsumption;
- [ ] OLM upgrade to v0.2.0 reaches Succeeded;
- [ ] post-upgrade reconciliation remains functional;
- [ ] uninstall removes Operator deployment;
- [ ] uninstall retains CRD, CR and managed resources;
- [ ] OpenShift Classic and OLM v1 manifests remain statically valid.

## Truth boundary

A successful Kind OLM lifecycle run proves the package/lifecycle mechanics on Kubernetes with OLM.

It does **not** by itself prove that the OLM lifecycle was executed on OpenShift. The separate I5 evidence already proves the Operator controller on OpenShift Local / CRC 4.22.7 under `restricted-v2`.

The strongest combined claim before a real CRC OLM replay is therefore:

`KIND_OLM_LIFECYCLE_PROVEN + OPENSHIFT_OPERATOR_RUNTIME_PROVEN_CONSUMER_1`.

Do not claim OpenShift OLM lifecycle runtime until a Catalog/Subscription or ClusterExtension installation is observed on CRC/OpenShift.
