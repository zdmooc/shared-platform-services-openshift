# Bootstrap Runbook

## Preconditions

- OpenShift/CRC reachable with `oc`;
- sufficient rights to create target namespaces;
- `kubectl` or `oc` with Kustomize support;
- Argo CD/OpenShift GitOps CRDs only when applying `gitops/`.

## Phase 1 — static validation

```bash
bash scripts/validate-platform.sh
```

## Phase 2 — namespaces

```bash
oc apply -k platform/base
```

## Phase 3 — GitOps

Apply GitOps manifests only when Argo CD/OpenShift GitOps CRDs exist.

```bash
oc api-resources | grep -E 'Application|AppProject|ApplicationSet'
oc apply -k gitops/base
```

## Phase 4 — shared capabilities

Apply each capability independently. Do not deploy all stateful services by default.

## Rollback

Delete only the capability introduced by the current change. Existing product-local dependencies remain available until consumer validation has passed.

## Evidence

Capture commands, timestamps, cluster context, pod status and test output under `evidence/<date>/<iteration>/`.
