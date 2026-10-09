#!/usr/bin/env bash
set -euo pipefail

# D-093 / I2: guarded deployment of the newly BUILT Operator digest on local CRC.
# Default readonly; apply requires a distinct authorization from image build.
mode="${OP3_I2_ROLLOUT_MODE:-readonly}"
case "$mode" in readonly|apply) ;; *) echo "ERROR: invalid mode" >&2; exit 2 ;; esac

ns=shared-platform-services
operator=mayabank-platform-operator
build_name=d093-op3-ssa-i2-1
tag=crc-i2-ssa-91e99136add2
repo=image-registry.openshift-image-registry.svc:5000/shared-platform-services/mayabank-platform-operator
old_image="$repo@sha256:ee3c1caed1d27642f11e7491a0e46442a08b0b6cb84df4258c4b7f52a8798d73"
expected_new="$repo@sha256:acfa316265a0c3466a67dfecc1b731ae6a7bed78689dbe39a14bdad10d80d3a1"
audit_dir="${D093_EVIDENCE_DIR:-/c/workspaces/d093-audit-readonly-20261008/i2-rollout}"
mkdir -p "$audit_dir"
log() { printf '%s\n' "$*"; }
die() { log "OP3_I2_ROLLOUT_BLOCKED=$*" >&2; exit 1; }
for tool in oc jq; do command -v "$tool" >/dev/null || die "missing $tool"; done

[[ "$(oc whoami --show-server)" == "https://api.crc.testing:6443" ]] || die "not CRC API"

oc -n "$ns" get deployment "$operator" -o json > "$audit_dir/deployment-before.json"
jq -e --arg old "$old_image" '
  .spec.replicas==1
  and .spec.strategy.type=="RollingUpdate"
  and .spec.template.spec.serviceAccountName=="mayabank-platform-operator"
  and ([.spec.template.spec.containers[] | select(.name=="manager")] | length==1 and .[0].image==$old)
  and (.status.availableReplicas // 0)==1
  and (.status.readyReplicas // 0)==1
' "$audit_dir/deployment-before.json" >/dev/null || die "running Deployment has unexpected image/health/spec"

# Exact Build and ImageStream tag must come from user's completed build.
oc -n "$ns" get build "$build_name" -o json > "$audit_dir/build-before.json"
jq -e --arg tag "mayabank-platform-operator:$tag" '
  .status.phase=="Complete"
  and .spec.output.to.kind=="ImageStreamTag"
  and .spec.output.to.name==$tag
' "$audit_dir/build-before.json" >/dev/null || die "build not complete or wrong destination"
oc -n "$ns" get imagestreamtag "mayabank-platform-operator:$tag" -o json > "$audit_dir/image-before.json"
new_image="$(jq -r '.image.dockerImageReference // empty' "$audit_dir/image-before.json")"
[[ "$new_image" == "$expected_new" ]] ||
  die "ImageStream tag digest differs from successfully built pinned artifact"
[[ "$new_image" != "$old_image" ]] || die "no new image"

oc get capabilityconsumption instant-payments-crc -o json > "$audit_dir/consumer-before.json"
jq -e '
  .metadata.generation==.status.observedGeneration
  and .spec.lifecycle.adoptionPolicy=="Manage"
  and .spec.lifecycle.deletionPolicy=="Retain"
  and .spec.target.namespace=="instant-payments-local"
  and any(.status.conditions[]?; .type=="Ready" and .status=="True" and .reason=="Reconciled")
' "$audit_dir/consumer-before.json" >/dev/null || die "consumer not healthy or unexpected intent"
oc -n instant-payments-local get resourcequota platform-quota -o json > "$audit_dir/quota-before.json"
jq -e '
  .spec.hard["requests.storage"]=="20Gi"
  and .metadata.labels["platform.mayabank.example/managed-by"]=="mayabank-platform-operator"
  and .metadata.labels["platform.mayabank.example/consumption"]=="instant-payments-crc"
' "$audit_dir/quota-before.json" >/dev/null || die "quota baseline/ownership mismatch"
oc -n instant-payments-local get deployment wero-ui -o json |
  jq -e '.spec.replicas==1 and (.status.availableReplicas // 0)==1' >/dev/null ||
  die "wero-ui not healthy 1/1"
oc -n openshift-gitops get application instant-payments-tech-lead-shared-platform -o json |
  jq -e '.status.sync.status=="Synced" and .status.health.status=="Healthy"' >/dev/null ||
  die "Argo not Synced/Healthy"

log "OP3_I2_ROLLOUT_OLD_DIGEST=$old_image"
log "OP3_I2_ROLLOUT_NEW_DIGEST=$new_image"
log "OP3_I2_ROLLOUT_EVIDENCE_DIR=$audit_dir"
log "OP3_I2_ROLLOUT_PREFLIGHT=PASS"
if [[ "$mode" == "readonly" ]]; then
  log "OP3_I2_ROLLOUT_READONLY=PASS"
  log "No Deployment or resource changed."
  exit 0
fi

[[ "${CONFIRM_OP3_I2_CRC_ROLLOUT:-}" == "YES_I_AUTHORIZE_CRC_OPERATOR_IMAGE_ROLLOUT" ]] ||
  die "separate rollout authorization absent"
[[ "$(oc auth can-i patch deployments.apps -n "$ns")" == "yes" ]] ||
  die "no permission to patch Deployment"

changed=false
success=false
rollback() {
  local exit_code=$?
  trap - EXIT
  if [[ "$changed" == "true" && "$success" != "true" ]]; then
    log "OP3_I2_ROLLOUT_FAILED=YES"
    log "OP3_I2_ROLLBACK_TARGET=$old_image"
    if oc -n "$ns" set image "deployment/$operator" "manager=$old_image" &&
      oc -n "$ns" rollout status "deployment/$operator" --timeout=180s &&
      oc -n "$ns" get deployment "$operator" -o json |
      jq -e --arg old "$old_image" '
        [.spec.template.spec.containers[] | select(.name=="manager")] |
        length==1 and .[0].image==$old
      ' >/dev/null; then
      log "OP3_I2_ROLLBACK=PASS_OLD_IMAGE_RESTORED"
    else
      log "OP3_I2_ROLLBACK=FAILED_MANUAL_INTERVENTION_REQUIRED" >&2
      exit 91
    fi
  fi
  exit "$exit_code"
}
trap rollback EXIT

log "OP3_I2_ROLLOUT_SCOPE=manager container image only"
# Mark as changed before the mutation so a partial write is also recovered.
changed=true
oc -n "$ns" set image "deployment/$operator" "manager=$new_image"
oc -n "$ns" rollout status "deployment/$operator" --timeout=240s

oc -n "$ns" get deployment "$operator" -o json > "$audit_dir/deployment-after.json"
jq -e --arg new "$new_image" '
  .spec.replicas==1
  and ([.spec.template.spec.containers[] | select(.name=="manager")] |
    length==1 and .[0].image==$new)
  and (.status.availableReplicas // 0)==1
  and (.status.readyReplicas // 0)==1
  and (.status.updatedReplicas // 0)==1
  and (.status.observedGeneration // 0)>=.metadata.generation
' "$audit_dir/deployment-after.json" >/dev/null ||
  die "rollout ended but new Deployment image/health is not verified"

oc get capabilityconsumption instant-payments-crc -o json > "$audit_dir/consumer-after.json"
jq -e '
  .metadata.generation==.status.observedGeneration
  and any(.status.conditions[]?; .type=="Ready" and .status=="True" and .reason=="Reconciled")
' "$audit_dir/consumer-after.json" >/dev/null || die "consumer not reconciled after rollout"
oc -n instant-payments-local get resourcequota platform-quota -o json |
  jq -e '.spec.hard["requests.storage"]=="20Gi"' >/dev/null ||
  die "quota changed after rollout"
oc -n instant-payments-local get deployment wero-ui -o json |
  jq -e '.spec.replicas==1 and (.status.availableReplicas // 0)==1' >/dev/null ||
  die "wero-ui changed after rollout"
oc -n openshift-gitops get application instant-payments-tech-lead-shared-platform -o json |
  jq -e '.status.sync.status=="Synced" and .status.health.status=="Healthy"' >/dev/null ||
  die "Argo not Synced/Healthy after rollout"

success=true
log "OP3_I2_OPERATOR_NEW_IMAGE_RUNTIME=PASS"
log "OP3_I2_PLATFORM_POST_ROLLOUT=PASS"
log "truth_boundary=PATCHED_IMAGE_DEPLOYED_NO_QUOTA_DRIFT_YET"
