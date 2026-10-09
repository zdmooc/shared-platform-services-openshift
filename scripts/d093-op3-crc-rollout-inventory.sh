#!/usr/bin/env bash
set -euo pipefail

# D-093 I2: READ-ONLY inventory before deciding how to replace a direct
# OpenShift Local Operator image. Does NOT touch GitOps, Pods or build configs.
log() { printf '%s\n' "$*"; }
for binary in oc jq; do
  command -v "$binary" >/dev/null || { log "ERROR: missing $binary" >&2; exit 1; }
done

api="$(oc whoami --show-server)"
[[ "$api" == "https://api.crc.testing:6443" ]] || {
  log "ERROR: expected local CRC API, observed: $api" >&2
  exit 18
}

namespace=shared-platform-services
operator=mayabank-platform-operator

log "===== D093 I2 CURRENT DEPLOYMENT / SA / IMAGE ====="
oc -n "$namespace" get deployment "$operator" -o json | jq '{
  name: .metadata.name,
  namespace: .metadata.namespace,
  resourceVersion: .metadata.resourceVersion,
  generation: .metadata.generation,
  replicas: .spec.replicas,
  available: .status.availableReplicas,
  serviceAccount: .spec.template.spec.serviceAccountName,
  strategy: .spec.strategy.type,
  containers: [.spec.template.spec.containers[] | {name,image,imagePullPolicy,args}]
}'

log "===== D093 I2 IMAGESTREAM (IF PRESENT) ====="
if oc -n "$namespace" get imagestream "$operator" -o json >/dev/null 2>&1; then
  oc -n "$namespace" get imagestream "$operator" -o json | jq '{
    name:.metadata.name,
    dockerImageRepository:.status.dockerImageRepository,
    tags:[.status.tags[]? | {tag, images:[.items[]? | {dockerImageReference,image}]}]
  }'
else
  log "OP3_ROLLOUT_IMAGESTREAM=NOT_FOUND"
fi

log "===== D093 I2 BUILD CONFIGURATIONS ====="
oc -n "$namespace" get buildconfig -o custom-columns=NAME:.metadata.name,STRATEGY:.spec.strategy.type,OUTPUT:.spec.output.to.name \
  --no-headers || true

log "===== D093 I2 OPERATOR POD ====="
oc -n "$namespace" get pods -l app.kubernetes.io/name=mayabank-platform-operator -o wide

log "===== D093 I2 CONTROLLER CONSUMER STATUS ====="
oc get capabilityconsumption instant-payments-crc -o json | jq '{
  generation:.metadata.generation,
  observedGeneration:.status.observedGeneration,
  ready:[.status.conditions[]? | select(.type=="Ready") | {status,reason,message}]
}'

log "===== D093 I2 PRODUCT / QUOTA / ARGO ====="
oc -n instant-payments-local get deployment wero-ui -o json |
  jq '{desired:.spec.replicas,available:.status.availableReplicas,ready:.status.readyReplicas}'
oc -n instant-payments-local get resourcequota platform-quota -o json |
  jq '{storage:.spec.hard["requests.storage"],labels:.metadata.labels}'
oc -n openshift-gitops get application instant-payments-tech-lead-shared-platform -o json |
  jq '{sync:.status.sync.status,health:.status.health.status}'

log "OP3_ROLLOUT_INVENTORY_READONLY=PASS"
log "No build, image push, Deployment change or cluster mutation executed."
