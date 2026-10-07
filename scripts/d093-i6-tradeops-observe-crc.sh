#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAMESPACE="${D093_TRADEOPS_NAMESPACE:-tradeops}"
CR_NAME="${D093_TRADEOPS_CR_NAME:-tradeops-crc}"
CR_FILE="${D093_TRADEOPS_CR_FILE:-consumers/tradeops/capability-consumption-crc-observe.yaml}"
TRADEOPS_REPO="${TRADEOPS_REPO:-$(cd "$ROOT/.." && pwd)/TradeOps-GenAI-Integration}"
OUT_ROOT="${D093_EVIDENCE_OUT_ROOT:-$ROOT/evidence/out}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$OUT_ROOT/d093-i6-tradeops-observe-$STAMP"

for cmd in oc python sha256sum grep awk; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "D093_I6_OBSERVE_FAIL missing_command=$cmd" >&2
    exit 2
  }
done

[[ -f "$CR_FILE" ]] || {
  echo "D093_I6_OBSERVE_FAIL missing_cr_file=$CR_FILE" >&2
  exit 2
}
if grep -Eq 'adoptionPolicy:[[:space:]]*Manage' "$CR_FILE"; then
  echo "D093_I6_OBSERVE_FAIL observe_cr_contains_manage" >&2
  exit 2
fi

# Preserve the PARK boundary established by D-090 T1/T2/G1/G2.
if [[ ! -f "$TRADEOPS_REPO/.runtime/tradeops-park/LATEST" ]]; then
  echo "D093_I6_OBSERVE_FAIL tradeops_park_snapshot_missing repo=$TRADEOPS_REPO" >&2
  exit 2
fi
PARK_SNAPSHOT="$(cat "$TRADEOPS_REPO/.runtime/tradeops-park/LATEST")"
if [[ ! -f "$PARK_SNAPSHOT/status" ]] || ! grep -qx 'PARKED' "$PARK_SNAPSHOT/status"; then
  echo "D093_I6_OBSERVE_FAIL tradeops_not_parked snapshot=$PARK_SNAPSHOT" >&2
  exit 2
fi
echo "D093_I6_TRADEOPS_PARK=PASS snapshot=$PARK_SNAPSHOT"

oc whoami >/dev/null
oc get namespace "$NAMESPACE" >/dev/null
oc get crd capabilityconsumptions.platform.mayabank.example >/dev/null
oc -n shared-platform-services wait --for=condition=Available   deploy/mayabank-platform-operator --timeout=120s >/dev/null
echo "D093_I6_OPERATOR_AVAILABLE=PASS"

mkdir -p "$OUT"

snapshot_namespace() {
  local dest="$1"
  local ns_json resources_json
  ns_json="$(oc get namespace "$NAMESPACE" -o json)"
  resources_json="$(
    oc -n "$NAMESPACE" get       deployments,statefulsets,services,pvc,networkpolicies,resourcequotas,limitranges,serviceaccounts,roles,rolebindings       -o json
  )"
  NS_JSON="$ns_json" RESOURCES_JSON="$resources_json" python - <<'PY' > "$dest"
import json, os

DROP_META = {
    "creationTimestamp",
    "generation",
    "managedFields",
    "resourceVersion",
    "selfLink",
    "uid",
}

def clean_meta(meta):
    return {
        k: v
        for k, v in meta.items()
        if k not in DROP_META
    }

ns = json.loads(os.environ["NS_JSON"])
resources = json.loads(os.environ["RESOURCES_JSON"])

out = {
    "namespace": {
        "apiVersion": ns.get("apiVersion"),
        "kind": ns.get("kind"),
        "metadata": clean_meta(ns.get("metadata", {})),
        "spec": ns.get("spec", {}),
    },
    "resources": [],
}

for item in resources.get("items", []):
    out["resources"].append(
        {
            "apiVersion": item.get("apiVersion"),
            "kind": item.get("kind"),
            "metadata": clean_meta(item.get("metadata", {})),
            "spec": item.get("spec", {}),
            "data": item.get("data", {}) if item.get("kind") == "ConfigMap" else {},
        }
    )

out["resources"].sort(
    key=lambda x: (
        x.get("kind", ""),
        x.get("metadata", {}).get("namespace", ""),
        x.get("metadata", {}).get("name", ""),
    )
)
print(json.dumps(out, sort_keys=True, separators=(",", ":")))
PY
}

snapshot_namespace "$OUT/01-before.json"
BEFORE_HASH="$(sha256sum "$OUT/01-before.json" | awk '{print $1}')"
echo "$BEFORE_HASH" > "$OUT/01-before.sha256"

oc -n "$NAMESPACE" get deployments,statefulsets,pvc -o wide   > "$OUT/02-protected-workloads-before.txt"
oc -n "$NAMESPACE" get resourcequota,limitrange,networkpolicy,serviceaccount,role,rolebinding   > "$OUT/03-platform-baseline-before.txt" 2>&1 || true

PREVIOUS_POLICY="$(oc get capabilityconsumption "$CR_NAME" -o jsonpath='{.spec.lifecycle.adoptionPolicy}' 2>/dev/null || true)"
if [[ "$PREVIOUS_POLICY" == "Manage" ]]; then
  echo "D093_I6_OBSERVE_FAIL preexisting_cr_is_manage name=$CR_NAME" >&2
  exit 1
fi
echo "D093_I6_PREEXISTING_CR_POLICY=${PREVIOUS_POLICY:-ABSENT}"

oc apply -f "$CR_FILE" >/dev/null
echo "D093_I6_OBSERVE_INTENT_APPLIED=PASS"

REASON=""
MESSAGE=""
for _ in $(seq 1 60); do
  REASON="$(
    oc get capabilityconsumption "$CR_NAME"       -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || true
  )"
  MESSAGE="$(
    oc get capabilityconsumption "$CR_NAME"       -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || true
  )"
  if [[ "$REASON" == "OwnershipConflict" || "$REASON" == "ObserveMode" ]]; then
    break
  fi
  sleep 2
done

if [[ "$REASON" != "OwnershipConflict" && "$REASON" != "ObserveMode" ]]; then
  oc get capabilityconsumption "$CR_NAME" -o yaml > "$OUT/04-capability-consumption.yaml" || true
  echo "D093_I6_OBSERVE_FAIL unexpected_ready_reason=${REASON:-missing}" >&2
  exit 1
fi

oc get capabilityconsumption "$CR_NAME" -o yaml > "$OUT/04-capability-consumption.yaml"
printf '%s
' "$MESSAGE" > "$OUT/05-ownership-inventory.txt"
echo "D093_I6_OBSERVE_REASON=$REASON"
echo "D093_I6_OWNERSHIP_INVENTORY=PASS"

MANAGED_REFS="$(
  oc get capabilityconsumption "$CR_NAME"     -o jsonpath='{range .status.managedResources[*]}{.kind}{"/"}{.namespace}{"/"}{.name}{"\n"}{end}'     2>/dev/null || true
)"
if [[ -n "$MANAGED_REFS" ]]; then
  printf '%s
' "$MANAGED_REFS" > "$OUT/06-unexpected-managed-resources.txt"
  echo "D093_I6_OBSERVE_FAIL managed_resources_present_in_observe" >&2
  exit 1
fi
echo "D093_I6_OBSERVE_MANAGED_RESOURCES=ZERO"

snapshot_namespace "$OUT/07-after.json"
AFTER_HASH="$(sha256sum "$OUT/07-after.json" | awk '{print $1}')"
echo "$AFTER_HASH" > "$OUT/07-after.sha256"

if [[ "$BEFORE_HASH" != "$AFTER_HASH" ]]; then
  python - "$OUT/01-before.json" "$OUT/07-after.json" <<'PY'
import json, sys
before=json.load(open(sys.argv[1],encoding="utf-8"))
after=json.load(open(sys.argv[2],encoding="utf-8"))
b={f'{x["kind"]}/{x["metadata"].get("name","")}':x for x in before["resources"]}
a={f'{x["kind"]}/{x["metadata"].get("name","")}':x for x in after["resources"]}
keys=sorted(set(b)|set(a))
for key in keys:
    if b.get(key) != a.get(key):
        print(key)
PY
  > "$OUT/08-namespace-diff-keys.txt"
  echo "D093_I6_OBSERVE_FAIL namespace_mutation_detected" >&2
  exit 1
fi
echo "D093_I6_ZERO_NAMESPACE_MUTATION=PASS"

# Explicitly prove protected product runtime assets remain product-owned and unchanged.
oc -n "$NAMESPACE" get deployments,statefulsets,pvc -o wide   > "$OUT/09-protected-workloads-after.txt"
if ! diff -u "$OUT/02-protected-workloads-before.txt" "$OUT/09-protected-workloads-after.txt"   > "$OUT/10-protected-workloads.diff"; then
  echo "D093_I6_OBSERVE_FAIL protected_workload_inventory_changed" >&2
  exit 1
fi
echo "D093_I6_PROTECTED_WORKLOADS_UNCHANGED=PASS"

# No platform baseline may be created by Observe.
PLATFORM_OWNED="$(
  oc -n "$NAMESPACE" get resourcequota,limitrange,networkpolicy,serviceaccount,role,rolebinding     -l platform.mayabank.example/consumption="$CR_NAME"     -o name 2>/dev/null || true
)"
if [[ -n "$PLATFORM_OWNED" ]]; then
  printf '%s
' "$PLATFORM_OWNED" > "$OUT/11-unexpected-platform-owned.txt"
  echo "D093_I6_OBSERVE_FAIL platform_resources_created_in_observe" >&2
  exit 1
fi
echo "D093_I6_PLATFORM_RESOURCES_CREATED=ZERO"

# Capture a bounded brownfield inventory for the later Manage decision.
oc -n "$NAMESPACE" get resourcequota,limitrange,networkpolicy,serviceaccount,role,rolebinding   -o custom-columns='KIND:.kind,NAME:.metadata.name,MANAGED_BY:.metadata.labels.platform\.mayabank\.example/managed-by,CONSUMPTION:.metadata.labels.platform\.mayabank\.example/consumption'   > "$OUT/12-brownfield-baseline-inventory.txt" 2>&1 || true

oc -n "$NAMESPACE" get pods,pvc -o wide > "$OUT/13-runtime-inventory.txt"
oc -n "$NAMESPACE" get statefulsets -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas'   > "$OUT/14-statefulsets.txt"

echo "D093_I6_TRADEOPS_OBSERVE=PASS"
echo "D093_I6_MANAGE=NOT_AUTHORIZED"
echo "D093_I6_EVIDENCE=$OUT"
