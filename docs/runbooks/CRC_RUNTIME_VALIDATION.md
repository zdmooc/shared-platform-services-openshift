# CRC / OpenShift Runtime Validation

**Status:** EXECUTION GATE DEFINED / NOT YET EXECUTED  
**Target claim after successful execution:** `CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY`

This runbook validates the Kubernetes-native **shared observability slice** on a real OpenShift Local / CRC cluster.

It does **not** prove the whole shared platform. In particular, it does not prove live shared Keycloak, SonarQube, Argo CD reconciliation, shared Kafka/PostgreSQL, multi-node HA, production resilience or enterprise federation.

## Preconditions

- CRC/OpenShift Local is running;

Recommended start sequence on the Windows/Git Bash workstation:

```bash
crc status
crc start
eval "$(crc oc-env)"
oc whoami --show-server
oc get clusterversion version
```

Do not continue if `oc get nodes` shows the Kind `edl-lab` nodes or if `clusterversion` is unavailable. That means the current kube/oc context is still Kubernetes/Kind rather than CRC/OpenShift.

- CRC/OpenShift Local is running;
- `oc` is logged in to the target cluster;
- current user can create namespaces and namespaced workloads used by the lab;
- `kubectl`, `oc`, Python 3 and Bash are available;
- repository checkout is on the intended commit.

The script accepts either a `python3` or `python` executable, which keeps the gate usable from Windows Git Bash environments.

## Preflight

```bash
oc whoami
oc whoami --show-server
oc get clusterversion version -o wide
oc get clusteroperators
oc get nodes -o wide
```

All ClusterOperators must be Available and not Degraded before the shared-platform smoke is promoted as evidence.

## Execute — direct smoke

```bash
bash scripts/runtime-smoke-openshift.sh
```

The script:

1. verifies OpenShift identity/API;
2. validates ClusterVersion and ClusterOperators;
3. applies `platform/runtime-ci`;
4. waits for the OTel Collector;
5. executes the consumer → OTLP → Collector → Prometheus-exporter smoke;
6. prints the cluster/runtime summary.

Expected markers:

```text
OTLP_HTTP_STATUS=200
OTEL_CONSUMER_PATH=PASS
OPENSHIFT_SHARED_PLATFORM_SMOKE=PASS
CRC_SHARED_OBSERVABILITY_RUNTIME=PASS
```

## Execute — recommended evidence wrapper

For the local workstation, use the wrapper so diagnostics are captured automatically:

```bash
bash scripts/run-crc-evidence.sh
```

It stores local raw evidence under `evidence/out/crc-<timestamp>/`. That directory is ignored by Git by default. Review and sanitize selected output before promoting any evidence into version control.

## Manual evidence capture

Equivalent commands:

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

Only after an observed successful CRC run with sanitized evidence may the matrix promote the exact slice to:

`CRC_RUNTIME_PROVEN_SHARED_OBSERVABILITY`.

The broader shared platform remains at its existing evidence levels until its own components are executed.

A CRC result remains:
- single-node/lab evidence;
- not HA evidence;
- not production evidence.
