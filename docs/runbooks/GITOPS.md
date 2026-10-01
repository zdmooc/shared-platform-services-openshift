# GitOps Runbook — S1

## Goal

One Argo CD/OpenShift GitOps control plane governs shared capabilities while products remain in their own repositories and namespaces.

## Safety

- Argo CD CRDs are prerequisites.
- Automatic prune is disabled in the generic consumer template.
- Consumer namespaces are not created implicitly.
- A product repository keeps ownership of product manifests.
- Platform repositories never rewrite product source code.

## Bootstrap

```bash
oc apply -k platform/base
oc apply -k gitops/base
```

Then copy `gitops/contracts/consumer-application-template.yaml` into a controlled consumer onboarding change and replace all `REPLACE_ME` values.

## Exit evidence

Record:
- `oc get appproject -n openshift-gitops shared-platform-services -o yaml`
- Argo CD application health/sync state
- target namespace
- commit SHA deployed
