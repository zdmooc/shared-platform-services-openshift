# CRC / OpenShift Runtime Validation

**Status:** EXECUTION GATE DEFINED / NOT YET EXECUTED  
**Target claim after successful execution:** `CRC_RUNTIME_PROVEN`

This runbook validates the Kubernetes-native shared-platform observability slice on a real OpenShift Local / CRC cluster.

It does not prove multi-node HA, production resilience or enterprise federation.

## Preconditions

- CRC/OpenShift Local is running;
- `oc` is logged in to the target cluster;
- current user can create namespaces and namespaced workloads used by the lab;
- `kubectl`, `oc`, Python 3 and Bash are available;
- repository checkout is on the intended commit.

## Preflight

```bash
oc whoami
oc whoami --show-server
oc get clusterversion version -o wide
oc get clusteroperators
oc get nodes -o wide
```

All ClusterOperators must be Available and not Degraded before the shared-platform smoke is promoted as evidence.

## Execute

```bash
bash scripts/runtime-smoke-openshift.sh
```

The script:

1. verifies OpenShift identity/API;
2. validates ClusterVersion and ClusterOperators;
3. applies `platform/runtime-ci`;
4. waits for the OTel Collector;
5. executes the same consumer → OTLP → Collector → Prometheus smoke used by Kind;
6. prints the cluster/runtime summary.

Expected markers:

```text
OTLP_HTTP_STATUS=200
OTEL_CONSUMER_PATH=PASS
OPENSHIFT_SHARED_PLATFORM_SMOKE=PASS
```

## Capture evidence

Use a timestamped local directory:

```bash
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="evidence/out/crc-$STAMP"
mkdir -p "$OUT"

bash scripts/runtime-smoke-openshift.sh | tee "$OUT/runtime-smoke.txt"
oc get clusterversion version -o yaml > "$OUT/clusterversion.yaml"
oc get clusteroperators -o yaml > "$OUT/clusteroperators.yaml"
oc get nodes -o wide > "$OUT/nodes.txt"
oc -n shared-observability get deploy,svc,pods -o wide > "$OUT/shared-observability.txt"
oc -n shared-observability logs deploy/otel-collector --tail=300 > "$OUT/otel-collector.log"
```

Do not commit tokens, kubeconfigs, credentials or private infrastructure details.

## Promotion rule

Only after an observed successful CRC run with archived evidence may the matrix be promoted to:

`CRC_RUNTIME_PROVEN`.

A CRC result remains:
- single-node/lab evidence;
- not HA evidence;
- not production evidence.
