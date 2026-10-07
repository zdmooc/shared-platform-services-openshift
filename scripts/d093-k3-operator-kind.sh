#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-d093-operator-ci}"
KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0}"
OPERATOR_IMAGE="${OPERATOR_IMAGE:-mayabank-platform-operator:ci}"
PORT_FORWARD_PID=""

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPERATOR_DIR="$ROOT_DIR/operators/platform-onboarding-operator"

diagnostics() {
  echo "== D-093 operator diagnostics =="
  if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "No reachable Kubernetes cluster; runtime diagnostics skipped."
    return 0
  fi
  kubectl get capabilityconsumptions.platform.mayabank.example -o wide || true
  kubectl get namespaces -o wide || true
  kubectl get resourcequota,limitrange,networkpolicy -A || true
  kubectl -n shared-platform-services get deploy,pod,sa || true
  kubectl -n shared-platform-services logs deploy/mayabank-platform-operator --tail=250 || true
  kubectl get events -A --sort-by=.lastTimestamp | tail -n 150 || true
}

cleanup() {
  status=$?
  if [[ -n "${PORT_FORWARD_PID}" ]]; then
    kill "${PORT_FORWARD_PID}" >/dev/null 2>&1 || true
  fi
  if [[ "$status" -ne 0 ]]; then
    diagnostics
  fi
  kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT

wait_reason() {
  local name="$1"
  local expected="$2"
  local reason=""
  for _ in $(seq 1 90); do
    reason="$(kubectl get capabilityconsumption "$name" -o json 2>/dev/null | jq -r '.status.conditions[]? | select(.type=="Ready") | .reason' | tail -n1 || true)"
    if [[ "$reason" == "$expected" ]]; then
      echo "CapabilityConsumption/$name Ready reason=$reason"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for CapabilityConsumption/$name reason=$expected; observed=$reason" >&2
  return 1
}

wait_condition() {
  local name="$1"
  local condition_type="$2"
  local expected_status="$3"
  local expected_reason="$4"
  local observed_status=""
  local observed_reason=""
  for _ in $(seq 1 90); do
    observed_status="$(kubectl get capabilityconsumption "$name" -o json 2>/dev/null | jq -r --arg t "$condition_type" '.status.conditions[]? | select(.type==$t) | .status' | tail -n1 || true)"
    observed_reason="$(kubectl get capabilityconsumption "$name" -o json 2>/dev/null | jq -r --arg t "$condition_type" '.status.conditions[]? | select(.type==$t) | .reason' | tail -n1 || true)"
    if [[ "$observed_status" == "$expected_status" && "$observed_reason" == "$expected_reason" ]]; then
      echo "CapabilityConsumption/$name $condition_type=$observed_status reason=$observed_reason"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for CapabilityConsumption/$name $condition_type=$expected_status reason=$expected_reason; observed=$observed_status/$observed_reason" >&2
  return 1
}


wait_resource() {
  for _ in $(seq 1 90); do
    if kubectl "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for: kubectl $*" >&2
  return 1
}

wait_quota_cpu() {
  local namespace="$1"
  local expected="$2"
  local observed=""
  for _ in $(seq 1 90); do
    observed="$(kubectl -n "$namespace" get resourcequota platform-quota -o json 2>/dev/null | jq -r '.spec.hard["requests.cpu"] // empty' || true)"
    if [[ "$observed" == "$expected" ]]; then
      echo "ResourceQuota/platform-quota requests.cpu=$observed"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for quota CPU $expected; observed=$observed" >&2
  return 1
}

echo "== Create Kubernetes 1.35 Kind cluster =="
kind create cluster --name "$CLUSTER_NAME" --image "$KIND_NODE_IMAGE" --wait 180s
kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl version

echo "== Build and load Platform Operator image =="
docker build -t "$OPERATOR_IMAGE" "$OPERATOR_DIR"
kind load docker-image "$OPERATOR_IMAGE" --name "$CLUSTER_NAME"

echo "== Install Shared Platform namespaces =="
kubectl apply -k "$ROOT_DIR/platform/base"

echo "== Install CapabilityConsumption CRD and RBAC =="
kubectl apply -k "$OPERATOR_DIR/config/crd"
kubectl wait --for=condition=Established crd/capabilityconsumptions.platform.mayabank.example --timeout=120s
kubectl apply -k "$OPERATOR_DIR/config/rbac"

echo "== Install Platform Operator manager =="
kubectl kustomize "$OPERATOR_DIR/config/manager"   | sed "s#ghcr.io/zdmooc/mayabank-platform-operator:dev#$OPERATOR_IMAGE#g"   | kubectl apply -f -
kubectl -n shared-platform-services rollout status deploy/mayabank-platform-operator --timeout=180s

echo "== I6A leader election proof =="
kubectl -n shared-platform-services scale deploy/mayabank-platform-operator --replicas=2
kubectl -n shared-platform-services rollout status deploy/mayabank-platform-operator --timeout=180s
for _ in $(seq 1 60); do
  holder="$(kubectl -n shared-platform-services get lease mayabank-platform-operator.platform.mayabank.example -o jsonpath='{.spec.holderIdentity}' 2>/dev/null || true)"
  if [[ -n "$holder" ]]; then
    break
  fi
  sleep 2
done
[[ -n "${holder:-}" ]]
echo "I6A_LEADER_ELECTION_LEASE=PASS holder=$holder"

echo "== I6A CRD validation negative test =="
if cat <<'YAML' | kubectl apply -f - >/tmp/i6a-invalid-cr.out 2>/tmp/i6a-invalid-cr.err
apiVersion: platform.mayabank.example/v1alpha1
kind: CapabilityConsumption
metadata:
  name: i6a-invalid-profile
spec:
  consumer:
    name: invalid
    environment: kind
  target:
    namespace: i6a-invalid
  identity: {mode: REFERENCE_ONLY}
  observability: {mode: REFERENCE_ONLY}
  secrets: {mode: REFERENCE_ONLY}
  gitops: {mode: REFERENCE_ONLY}
  quality: {mode: REFERENCE_ONLY}
  eventing: {mode: REFERENCE_ONLY}
  database: {mode: REFERENCE_ONLY}
  objectStorage: {mode: REFERENCE_ONLY}
  resources:
    profile: xlarge
  network:
    profile: restricted
  lifecycle:
    adoptionPolicy: Observe
    deletionPolicy: Retain
YAML
then
  echo "invalid resource profile unexpectedly accepted" >&2
  cat /tmp/i6a-invalid-cr.out >&2 || true
  exit 1
fi
grep -Eq 'Unsupported value|supported values|must be' /tmp/i6a-invalid-cr.err
echo "I6A_CRD_VALIDATION=PASS"

echo "== I4 greenfield Manage =="
cat <<'YAML' | kubectl apply -f -
apiVersion: platform.mayabank.example/v1alpha1
kind: CapabilityConsumption
metadata:
  name: instant-payments-kind
spec:
  consumer:
    name: instant-payments
    owner: payments
    environment: kind
  target:
    namespace: d093-greenfield
  identity:
    mode: CONSUME_SHARED
  observability:
    mode: CONSUME_SHARED
  secrets:
    mode: REFERENCE_ONLY
  gitops:
    mode: CONSUME_SHARED
  quality:
    mode: REFERENCE_ONLY
  eventing:
    mode: DEDICATED_FOR_TEST
  database:
    mode: DEDICATED_FOR_TEST
  objectStorage:
    mode: REFERENCE_ONLY
  resources:
    profile: small
  network:
    profile: restricted
  lifecycle:
    adoptionPolicy: Manage
    deletionPolicy: Retain
YAML

wait_reason instant-payments-kind Reconciled
kubectl get namespace d093-greenfield
kubectl -n d093-greenfield get serviceaccount,role,rolebinding,resourcequota,limitrange,networkpolicy
wait_quota_cpu d093-greenfield 2

managed_by="$(kubectl -n d093-greenfield get resourcequota platform-quota -o json | jq -r '.metadata.labels["platform.mayabank.example/managed-by"]')"
[[ "$managed_by" == "mayabank-platform-operator" ]]
kubectl -n d093-greenfield get resourcequota platform-quota -o json --show-managed-fields=true \
  | jq -e '.metadata.managedFields[]? | select(.manager=="mayabank-platform-operator" and .operation=="Apply")' >/dev/null

echo "K3_KIND_MANAGE=PASS"
echo "K3_KIND_SSA_FIELD_MANAGER=PASS"

echo "== I6A controller metrics proof =="
kubectl -n shared-platform-services port-forward deploy/mayabank-platform-operator 18080:8080 >/tmp/i6a-metrics-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:18080/metrics >/tmp/i6a-metrics.txt 2>/dev/null; then
    break
  fi
  sleep 1
done
grep -q 'mayabank_platform_operator_reconcile_total' /tmp/i6a-metrics.txt
grep -q 'mayabank_platform_operator_reconcile_duration_seconds' /tmp/i6a-metrics.txt
kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
PORT_FORWARD_PID=""
echo "I6A_OPERATOR_METRICS=PASS"

echo "== I6B transient RBAC apply failure -> automatic controller-runtime retry =="
rbac_rule_index="$(kubectl get clusterrole mayabank-platform-operator -o json | jq -r '.rules | to_entries[] | select(.value.apiGroups | index("rbac.authorization.k8s.io")) | .key' | head -n1)"
[[ "$rbac_rule_index" =~ ^[0-9]+$ ]]
original_rbac_verbs="$(kubectl get clusterrole mayabank-platform-operator -o json | jq -c ".rules[$rbac_rule_index].verbs")"
denied_rbac_verbs="$(printf '%s' "$original_rbac_verbs" | jq -c 'map(select(. != "create"))')"
kubectl patch clusterrole mayabank-platform-operator --type=json   -p="[{"op":"replace","path":"/rules/$rbac_rule_index/verbs","value":$denied_rbac_verbs}]"

cat <<'YAML' | kubectl apply -f -
apiVersion: platform.mayabank.example/v1alpha1
kind: CapabilityConsumption
metadata:
  name: i6b-transient-kind
spec:
  consumer:
    name: i6b-transient
    owner: platform-engineering
    environment: kind
  target:
    namespace: d093-i6b-transient
  identity:
    mode: REFERENCE_ONLY
  observability:
    mode: REFERENCE_ONLY
  secrets:
    mode: REFERENCE_ONLY
  gitops:
    mode: REFERENCE_ONLY
  quality:
    mode: REFERENCE_ONLY
  eventing:
    mode: REFERENCE_ONLY
  database:
    mode: REFERENCE_ONLY
  objectStorage:
    mode: REFERENCE_ONLY
  resources:
    profile: small
  network:
    profile: restricted
  lifecycle:
    adoptionPolicy: Manage
    deletionPolicy: Retain
YAML

wait_condition i6b-transient-kind Ready False ApplyFailed
wait_condition i6b-transient-kind Degraded True ApplyFailed
kubectl get namespace d093-i6b-transient
kubectl -n d093-i6b-transient get serviceaccount platform-consumer
if kubectl -n d093-i6b-transient get role platform-consumer-read >/dev/null 2>&1; then
  echo "Role unexpectedly created while RBAC create permission was removed" >&2
  exit 1
fi
echo "I6B_TRANSIENT_APPLY_FAILURE_OBSERVED=PASS"

kubectl patch clusterrole mayabank-platform-operator --type=json   -p="[{"op":"replace","path":"/rules/$rbac_rule_index/verbs","value":$original_rbac_verbs}]"

# No CR patch/update here: convergence must come from controller-runtime's queued retry.
wait_reason i6b-transient-kind Reconciled
wait_condition i6b-transient-kind Degraded False Healthy
wait_resource -n d093-i6b-transient get role platform-consumer-read
echo "I6B_AUTOMATIC_RETRY_RECOVERY=PASS"

echo "== I6B retryable failure metric =="
current_holder="$(kubectl -n shared-platform-services get lease mayabank-platform-operator.platform.mayabank.example -o jsonpath='{.spec.holderIdentity}')"
current_leader_pod="${current_holder%%_*}"
kubectl -n shared-platform-services port-forward "pod/$current_leader_pod" 18081:8080 >/tmp/i6b-metrics-port-forward.log 2>&1 &
PORT_FORWARD_PID=$!
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:18081/metrics >/tmp/i6b-metrics.txt 2>/dev/null; then
    break
  fi
  sleep 1
done
grep -Eq 'mayabank_platform_operator_retryable_failures_total\{stage="apply"\} [1-9][0-9]*(\.[0-9]+)?' /tmp/i6b-metrics.txt
kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
PORT_FORWARD_PID=""
echo "I6B_RETRYABLE_FAILURE_METRIC=PASS"

echo "== I6B leader loss -> failover -> reconciliation continuity =="
holder_before="$(kubectl -n shared-platform-services get lease mayabank-platform-operator.platform.mayabank.example -o jsonpath='{.spec.holderIdentity}')"
leader_pod_before="${holder_before%%_*}"
kubectl -n shared-platform-services delete pod "$leader_pod_before" --wait=true

holder_after=""
for _ in $(seq 1 90); do
  holder_after="$(kubectl -n shared-platform-services get lease mayabank-platform-operator.platform.mayabank.example -o jsonpath='{.spec.holderIdentity}' 2>/dev/null || true)"
  if [[ -n "$holder_after" && "$holder_after" != "$holder_before" ]]; then
    break
  fi
  sleep 2
done
[[ -n "$holder_after" && "$holder_after" != "$holder_before" ]]
kubectl -n shared-platform-services rollout status deploy/mayabank-platform-operator --timeout=180s
echo "I6B_LEADER_FAILOVER=PASS before=$holder_before after=$holder_after"

kubectl -n d093-greenfield delete resourcequota platform-quota
wait_resource -n d093-greenfield get resourcequota platform-quota
wait_quota_cpu d093-greenfield 2
wait_reason instant-payments-kind Reconciled
echo "I6B_POST_FAILOVER_RECONCILIATION=PASS"

echo "== I4 update declared resource profile =="
kubectl patch capabilityconsumption instant-payments-kind --type=merge   -p '{"spec":{"resources":{"profile":"medium"}}}'
wait_quota_cpu d093-greenfield 4
echo "K3_KIND_UPDATE=PASS"

echo "== I4 drift/delete recovery =="
kubectl -n d093-greenfield delete resourcequota platform-quota
wait_resource -n d093-greenfield get resourcequota platform-quota
wait_quota_cpu d093-greenfield 4
echo "K3_KIND_DRIFT_RECOVERY=PASS"

echo "== I4 controller restart + continued reconciliation =="
kubectl -n shared-platform-services rollout restart deploy/mayabank-platform-operator
kubectl -n shared-platform-services rollout status deploy/mayabank-platform-operator --timeout=180s
kubectl -n d093-greenfield delete limitrange platform-defaults
wait_resource -n d093-greenfield get limitrange platform-defaults
wait_reason instant-payments-kind Reconciled
echo "K3_KIND_CONTROLLER_RESTART=PASS"

echo "== I4 brownfield Observe =="
kubectl create namespace d093-brownfield
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tradeops-runtime
  namespace: d093-brownfield
spec:
  hard:
    requests.cpu: "6"
    requests.memory: 10Gi
---
apiVersion: v1
kind: LimitRange
metadata:
  name: tradeops-defaults
  namespace: d093-brownfield
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 50m
        memory: 64Mi
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: d093-brownfield
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
YAML

cat <<'YAML' | kubectl apply -f -
apiVersion: platform.mayabank.example/v1alpha1
kind: CapabilityConsumption
metadata:
  name: tradeops-brownfield-kind
spec:
  consumer:
    name: tradeops
    owner: ai-platform
    environment: kind
  target:
    namespace: d093-brownfield
  identity:
    mode: CONSUME_SHARED
  observability:
    mode: CONSUME_SHARED
  secrets:
    mode: REFERENCE_ONLY
  gitops:
    mode: CONSUME_SHARED
  quality:
    mode: REFERENCE_ONLY
  eventing:
    mode: DEDICATED_FOR_TEST
  database:
    mode: DEDICATED_FOR_TEST
  objectStorage:
    mode: REFERENCE_ONLY
  resources:
    profile: ai-medium
  network:
    profile: restricted
  lifecycle:
    adoptionPolicy: Observe
    deletionPolicy: Retain
YAML

wait_reason tradeops-brownfield-kind OwnershipConflict
if kubectl -n d093-brownfield get resourcequota platform-quota >/dev/null 2>&1; then
  echo "Observe mode mutated brownfield namespace" >&2
  exit 1
fi
echo "K3_KIND_BROWNFIELD_OBSERVE=PASS"
echo "K3_KIND_OWNERSHIP_CONFLICT=PASS"

echo "== I4 explicit brownfield migration then Manage =="
kubectl -n d093-brownfield delete resourcequota tradeops-runtime
kubectl -n d093-brownfield delete limitrange tradeops-defaults
kubectl -n d093-brownfield delete networkpolicy default-deny
kubectl patch capabilityconsumption tradeops-brownfield-kind --type=merge   -p '{"spec":{"lifecycle":{"adoptionPolicy":"Manage"}}}'
wait_reason tradeops-brownfield-kind Reconciled
wait_quota_cpu d093-brownfield 6
namespace_owner="$(kubectl get namespace d093-brownfield -o json | jq -r '.metadata.labels["platform.mayabank.example/consumption"]')"
[[ "$namespace_owner" == "tradeops-brownfield-kind" ]]
echo "K3_KIND_BROWNFIELD_ADOPTION=PASS"

echo "== I4 Retain deletion boundary =="
kubectl delete capabilityconsumption tradeops-brownfield-kind
wait_resource get namespace d093-brownfield
wait_resource -n d093-brownfield get resourcequota platform-quota
echo "K3_KIND_RETAIN=PASS"

echo "== Final operator runtime snapshot =="
kubectl get capabilityconsumption -o wide
kubectl -n shared-platform-services get deploy,pod
kubectl -n d093-greenfield get resourcequota,limitrange,networkpolicy
kubectl -n d093-brownfield get resourcequota,limitrange,networkpolicy

echo "K3_KIND_OPERATOR_READY=PASS"
echo "K3_KIND_RUNTIME_RESULT=PASS"
echo "claim=KIND_RUNTIME_PROVEN_PLATFORM_OPERATOR"
echo "i6a_leader_election=KIND_RUNTIME_PROVEN"
echo "i6a_metrics=KIND_RUNTIME_PROVEN"
echo "i6b_retry_recovery=KIND_RUNTIME_PROVEN"
echo "i6b_leader_failover=KIND_RUNTIME_PROVEN"
echo "i6b_day2=KIND_RUNTIME_PROVEN"
echo "crc_claim=NOT_PROVEN_BY_THIS_KIND_RUN"
echo "crc_external_evidence=CONSUMER_1_CRC_RUNTIME_PROVEN"
