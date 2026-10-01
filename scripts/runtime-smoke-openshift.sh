#!/usr/bin/env bash
set -euo pipefail

command -v oc >/dev/null 2>&1 || { echo "oc CLI is required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl CLI is required"; exit 1; }

echo "== OpenShift identity and API"
oc whoami
oc whoami --show-server

echo "== ClusterVersion"
oc get clusterversion version -o wide

echo "== ClusterOperators"
oc get clusteroperators

bad_operators="$(oc get clusteroperators -o json | python3 -c '
import json,sys
data=json.load(sys.stdin)
bad=[]
for item in data["items"]:
    cond={c["type"]:c["status"] for c in item.get("status",{}).get("conditions",[])}
    if cond.get("Available") != "True" or cond.get("Degraded") == "True":
        bad.append(item["metadata"]["name"])
print("\n".join(bad))
')"

if [[ -n "${bad_operators}" ]]; then
  echo "ERROR: unhealthy ClusterOperators"
  echo "${bad_operators}"
  exit 1
fi

echo "== Apply Kubernetes-native shared-platform runtime slice"
oc apply -k platform/runtime-ci
oc -n shared-observability rollout status deploy/otel-collector --timeout=180s

echo "== Prove consumer telemetry path on OpenShift"
bash scripts/smoke-otel-consumer.sh

echo "== Capture cluster/runtime summary"
oc get nodes -o wide
oc get namespaces shared-platform-services shared-observability shared-identity shared-quality
oc -n shared-observability get deploy,svc,pods -o wide

echo "OPENSHIFT_SHARED_PLATFORM_SMOKE=PASS"
echo "claim=CRC_RUNTIME_PROVEN only when executed on CRC and evidence is stored"
