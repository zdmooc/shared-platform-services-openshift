# AKS Runtime Validation — Shared Platform Services

**Date:** 2026-10-01  
**Status:** A3 PREPARED / AKS RUNTIME NOT PROVEN

This runbook promotes the Kubernetes-portable slice of Shared Platform Services onto an AKS cluster created and qualified by the canonical Azure/Cluster Factory owners.

## Preconditions

- AKS cluster exists;
- current `kubectl` context explicitly points to the intended ephemeral AKS cluster;
- cluster health gate has passed;
- caller has sufficient rights to create the lab namespaces/resources;
- no customer data or static cloud credentials are used.

Check:

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get --raw='/readyz'
```

## Phase 1 — static validation

```bash
bash scripts/validate-platform.sh
```

## Phase 2 — portable base

```bash
kubectl apply -k platform/base
```

Verify:

```bash
kubectl get ns
kubectl get all -n shared-platform-services
```

## Phase 3 — shared observability slice

```bash
kubectl apply -k platform/observability/otel
```

Run the existing consumer smoke where compatible:

```bash
bash scripts/smoke-otel-consumer.sh
```

Expected evidence:
- collector Ready;
- in-cluster consumer reaches the OTLP endpoint;
- exported metric visible on the collector Prometheus endpoint.

## Phase 4 — GitOps / IAM / quality

Add only the capabilities required by the demonstration.

Do not install a complete platform catalog simply to increase the number of running products.

Argo CD, Keycloak and SonarQube deep expertise remain owned by their specialist repositories. This repository owns the shared integration contract.

## Phase 5 — consumer

First target:
`zdmooc/mayabank-instant-payments-resilience-platform`.

Initial AKS scope:
- consume shared observability;
- preserve the standalone CRC overlay;
- keep payment Kafka/PostgreSQL dedicated while payment resilience/correctness is under test.

## Evidence

Store or export:
- cluster context and Kubernetes version;
- namespaces;
- platform pod status;
- collector logs;
- consumer OTLP HTTP result;
- exposed smoke metric;
- timestamps;
- rollback result.

Allowed claim only after observed success:

`CLOUD_RUNTIME_PROVEN_AKS_SHARED_OBSERVABILITY`

This does not prove production HA, multi-region, client architecture or OpenShift.

## Rollback

Remove only the capabilities introduced by the current AKS lab. Product-local dependencies must remain reproducible independently.

The Azure owner remains responsible for final cloud retirement and residual-resource verification.
