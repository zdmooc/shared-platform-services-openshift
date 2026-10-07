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

- [x] bundle v0.1.0 passes `operator-sdk bundle validate`;
- [x] bundle v0.2.0 passes `operator-sdk bundle validate`;
- [x] FBC passes `opm validate`;
- [x] bundle and catalog images build;
- [x] existing Go/envtest/I6B tests remain green;
- [x] OLM installs on Kind;
- [x] v0.1.0 CSV reaches Succeeded;
- [x] Operator reconciles a real CapabilityConsumption;
- [x] OLM upgrade to v0.2.0 reaches Succeeded;
- [x] post-upgrade reconciliation remains functional;
- [x] uninstall removes Operator deployment;
- [x] uninstall retains CRD, CR and managed resources;
- [x] OpenShift Classic and OLM v1 manifests remain statically valid.

## Runtime evidence

Validated on branch `d093-i6c-olm-openshift-packaging`, code head `4918b2e8d2c10d8203fbcf581f963a8a38f80545`:

- Platform CI `37599472773` — **SUCCESS**;
- D093 K3 Operator Kind Runtime `37599472784` — **SUCCESS**;
- D093 I6C OLM Lifecycle `37599472919` — **SUCCESS**.

Observed lifecycle markers include:
- `I6C_BUNDLE_VALIDATION=PASS`;
- `I6C_OLM_INSTALL=PASS`;
- `I6C_OLM_V010_INSTALL=PASS`;
- `I6C_OLM_CONSUMER_RECONCILE=PASS`;
- `I6C_OLM_UPGRADE=PASS`;
- `I6C_POST_UPGRADE_RECONCILIATION=PASS`;
- `I6C_UNINSTALL_RETAIN=PASS`;
- `I6C_KIND_OLM_LIFECYCLE_RESULT=PASS`.

Allowed branch-level combined claim:
`KIND_OLM_LIFECYCLE_PROVEN + OPENSHIFT_OPERATOR_RUNTIME_PROVEN_CONSUMER_1`.

Promotion to `main` is pending PR #10 merge.

## Truth boundary

A successful Kind OLM lifecycle run proves the package/lifecycle mechanics on Kubernetes with OLM.

It does **not** by itself prove that the OLM lifecycle was executed on OpenShift. The separate I5 evidence already proves the Operator controller on OpenShift Local / CRC 4.22.7 under `restricted-v2`.

The strongest combined claim before a real CRC OLM replay is therefore:

`KIND_OLM_LIFECYCLE_PROVEN + OPENSHIFT_OPERATOR_RUNTIME_PROVEN_CONSUMER_1`.

Do not claim OpenShift OLM lifecycle runtime until a Catalog/Subscription or ClusterExtension installation is observed on CRC/OpenShift.
