# OpenShift OLM installation surfaces

## OpenShift 4.22

OpenShift 4.22 exposes both OLM Classic concepts and the newer OLM v1 extension APIs.

### OLM Classic

Use `openshift-classic/` when demonstrating the established OperatorHub lifecycle:

```text
CatalogSource -> Subscription -> InstallPlan -> ClusterServiceVersion -> Deployment
```

The package installs cluster-wide because `CapabilityConsumption` is cluster-scoped and the Operator reconciles platform-owned resources across consumer namespaces.

### OLM v1

Use `openshift-v1/` for the newer OpenShift 4.22 extension model:

```text
ClusterCatalog -> ClusterExtension
```

The `ClusterExtension` references a dedicated installer service account. This repository intentionally does **not** bind that account to `cluster-admin`. The target OpenShift environment must grant only the installation permissions required by the bundle according to local platform governance.

## Image publication boundary

The manifests use these target images:

- `ghcr.io/zdmooc/mayabank-platform-operator:v0.2.0`;
- `ghcr.io/zdmooc/mayabank-platform-operator-bundle:v0.2.0`;
- `ghcr.io/zdmooc/mayabank-platform-operator-catalog:v0.2.0`.

The files are deployable contracts. A public registry publication is a separate release gate and must not be claimed until the images are actually pushed and pull-tested.

## Uninstall boundary

Removing the Operator must not be presented as permission to delete consumer resources. The V1 platform contract remains `deletionPolicy=Retain`. Operator removal and data/resource cleanup are separate administrative decisions.
