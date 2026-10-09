#!/usr/bin/env bash
set -euo pipefail

# D-093/I2: build a NEW OpenShift internal-registry image from the
# CI-validated OP3 source commit. Never update the running Deployment.
# Default mode is read-only; build mode requires a separate exact consent.
mode="${OP3_I2_MODE:-readonly}"
case "$mode" in
  readonly|build) ;;
  *) echo "ERROR: OP3_I2_MODE must be readonly or build" >&2; exit 2 ;;
esac

source_sha="${OP3_I2_SOURCE_SHA:-91e99136add2f3af6ee3c03373445abc93d23654}"
ns=shared-platform-services
operator=mayabank-platform-operator
old_image="image-registry.openshift-image-registry.svc:5000/${ns}/${operator}@sha256:ee3c1caed1d27642f11e7491a0e46442a08b0b6cb84df4258c4b7f52a8798d73"
bc=d093-op3-ssa-i2
tag="crc-i2-ssa-${source_sha:0:12}"
audit_dir="${D093_EVIDENCE_DIR:-/c/workspaces/d093-audit-readonly-20261008/i2-binary-build}"
mkdir -p "$audit_dir"

log() { printf '%s\n' "$*"; }
fail() { log "OP3_I2_BUILD_ABORTED=$*" >&2; exit 1; }

for cmd in git oc jq tar mktemp; do
  command -v "$cmd" >/dev/null || fail "required command not found: $cmd"
done
[[ "$source_sha" =~ ^[0-9a-f]{40}$ ]] || fail "source SHA must be an exact 40-character commit"
[[ "$(oc whoami --show-server)" == "https://api.crc.testing:6443" ]] ||
  fail "refusing to build on a non-CRC API server"

# Work from caller's Git checkout; do not alter, reset or switch main.
git rev-parse --is-inside-work-tree >/dev/null || fail "run from Git checkout"
git cat-file -e "${source_sha}^{commit}" 2>/dev/null || fail "pinned commit missing: git fetch origin"
git cat-file -e "${source_sha}:operators/platform-onboarding-operator/Dockerfile" ||
  fail "operator Dockerfile missing at pinned source SHA"
git show "${source_sha}:operators/platform-onboarding-operator/internal/controller/capabilityconsumption_controller.go" |
  grep -q 'quotaStorageIsOnlyHardLimitDrift' ||
  fail "source has not included the reviewed SSA storage-only guard"
git show "${source_sha}:operators/platform-onboarding-operator/internal/controller/ssa_quota_recovery_test.go" |
  grep -q 'TestManagedQuotaMixedStorageAndCPUDriftNeverForces' ||
  fail "source does not include mandatory mixed-drift regression"

oc -n "$ns" get deployment "$operator" -o json > "$audit_dir/operator-before.json"
jq -e --arg old "$old_image" '
  [.spec.template.spec.containers[] | select(.name=="manager")] |
  length==1 and .[0].image==$old
' "$audit_dir/operator-before.json" >/dev/null ||
  fail "running image changed; stop on stale inventory"
jq -e '(.status.readyReplicas // 0)==1 and (.status.availableReplicas // 0)==1' \
  "$audit_dir/operator-before.json" >/dev/null ||
  fail "direct operator is not 1/1 healthy"

oc get capabilityconsumption instant-payments-crc -o json > "$audit_dir/consumer-before.json"
jq -e '
  .spec.lifecycle.adoptionPolicy=="Manage"
  and .spec.target.namespace=="instant-payments-local"
  and .metadata.generation==.status.observedGeneration
  and any(.status.conditions[]?;
    .type=="Ready" and .status=="True" and .reason=="Reconciled")
' "$audit_dir/consumer-before.json" >/dev/null ||
  fail "consumer not Ready/Reconciled"
oc -n instant-payments-local get resourcequota platform-quota -o json |
  jq -e '.spec.hard["requests.storage"]=="20Gi"' >/dev/null ||
  fail "platform quota not at 20Gi"
oc -n openshift-gitops get application instant-payments-tech-lead-shared-platform -o json |
  jq -e '.status.sync.status=="Synced" and .status.health.status=="Healthy"' >/dev/null ||
  fail "Argo application not Synced/Healthy"

if oc -n "$ns" get buildconfig "$bc" >/dev/null 2>&1; then
  fail "dedicated BuildConfig already exists; refuse overwrite"
fi
if oc -n "$ns" get imagestreamtag "${operator}:${tag}" >/dev/null 2>&1; then
  fail "pinned image tag already exists; refuse overwrite"
fi

log "OP3_I2_SOURCE_COMMIT=$source_sha"
log "OP3_I2_ORIGINAL_IMAGE=$old_image"
log "OP3_I2_TARGET_IMAGESTREAM_TAG=${operator}:${tag}"
log "OP3_I2_EVIDENCE_DIR=$audit_dir"
log "OP3_I2_BUILD_PREFLIGHT=PASS"

if [[ "$mode" == "readonly" ]]; then
  log "OP3_I2_BUILD_READONLY=PASS"
  log "No BuildConfig, Build, ImageStream tag or Deployment mutated."
  exit 0
fi

[[ "${CONFIRM_OP3_I2_BINARY_BUILD:-}" == "YES_I_AUTHORIZE_CRC_BUILD_NO_DEPLOY" ]] ||
  fail "missing separate binary build authorization token"
[[ "$(oc auth can-i create buildconfigs -n "$ns")" == "yes" ]] ||
  fail "user cannot create BuildConfigs in target namespace"
[[ "$(oc auth can-i create builds -n "$ns")" == "yes" ]] ||
  fail "user cannot create Builds in target namespace"

# Archive precisely the pinned Operator sub-tree, not the local main checkout.
# Keep the immutable source/context as local evidence.
context_dir="$(mktemp -d "$audit_dir/operator-source-${source_sha:0:12}-XXXXXX")"
git archive "${source_sha}:operators/platform-onboarding-operator" | tar -xf - -C "$context_dir"
[[ -s "$context_dir/Dockerfile" && -s "$context_dir/go.mod" && -s "$context_dir/go.sum" ]] ||
  fail "incomplete archived binary build context"

log "OP3_I2_SOURCE_CONTEXT=$context_dir"
log "OP3_I2_BUILD_MUTATION_SCOPE=dedicated BuildConfig/Build and NEW ImageStream tag only"
oc -n "$ns" new-build --binary --strategy=docker --name="$bc" \
  --to="${operator}:${tag}"
oc -n "$ns" get buildconfig "$bc" -o json > "$audit_dir/buildconfig.json"
jq -e --arg dest "${operator}:${tag}" '
  .spec.source.type=="Binary"
  and .spec.strategy.type=="Docker"
  and .spec.output.to.kind=="ImageStreamTag"
  and .spec.output.to.name==$dest
' "$audit_dir/buildconfig.json" >/dev/null ||
  fail "generated BuildConfig output/strategy not as expected"

log "OP3_I2_BINARY_BUILD_STARTED=PASS"
oc -n "$ns" start-build "$bc" --from-dir="$context_dir" --follow --wait
oc -n "$ns" get imagestreamtag "${operator}:${tag}" -o json > "$audit_dir/new-imagestreamtag.json"
reference="$(jq -r '.image.dockerImageReference // empty' "$audit_dir/new-imagestreamtag.json")"
[[ "$reference" == *"@sha256:"* ]] ||
  fail "image digest missing even though build command completed"
log "OP3_I2_NEW_IMAGE_DIGEST=$reference"
log "OP3_I2_BINARY_IMAGE_BUILT=PASS"
log "truth_boundary=IMAGE_BUILT_NOT_DEPLOYED"
