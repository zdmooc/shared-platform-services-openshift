# DAAROPS OP2 — OLM Lifecycle Replay on OpenShift Local / CRC

Date: 2026-10-07  
Status: **IMPLEMENTED / CRC RUNTIME PENDING**

## Goal

Close the only material OLM evidence gap left after I6C:

```text
KIND_OLM_LIFECYCLE_PROVEN
+
OPENSHIFT_OPERATOR_RUNTIME_PROVEN_CONSUMER_1
        |
        v
OP2
exact OLM install / upgrade / uninstall on CRC/OpenShift
```

The runtime claim is promoted only after the script completes on the user's OpenShift Local / CRC cluster.

## Read-only preflight — execute before any CRC window

```bash
OP2_PREFLIGHT_ONLY=true bash scripts/d093-op2-olm-crc.sh
```

Expected marker: `OP2_PREFLIGHT_READONLY=PASS`. This mode verifies OpenShift/OLM APIs, GHCR image pullability, and that dedicated test names are unused; it exits **before scaling, applying, or deleting anything**. Pre-existing names make it fail safely. A separate CI regression uses mocked `oc` to check this property. The availability of images must still be confirmed against the actual CRC runtime.

## Full mutating lifecycle — explicit authorization required

```bash
CONFIRM_OP2_CRC_MUTATIONS=YES_I_AUTHORIZE_OP2_OPERATOR_PARK_AND_TEST_CLEANUP \
  bash scripts/d093-op2-olm-crc.sh
```

Never run this second command automatically: it scales the existing direct Operator to zero, creates test resources, deletes a test quota for reconstruction, uninstalls OLM resources and cleans only its own test namespaces. Use a controlled CRC window, capture the original state and obtain explicit authorization first.

Required local tools:

- `oc` authenticated to the target CRC/OpenShift cluster;
- `jq`;
- `operator-sdk` compatible with the current bundle baseline.

## Safety model

The existing direct Operator deployment can conflict with a second AllNamespaces OLM-managed controller.

The script therefore:

1. records the current direct Operator replica count;
2. scales the direct deployment to zero;
3. installs the OLM-managed Operator in the isolated `d093-op2-olm` namespace;
4. exercises only a dedicated OP2 consumer/namespace;
5. uninstalls the OLM Operator;
6. verifies CRD/CR/managed-resource retention;
7. removes dedicated test namespaces unless `KEEP_TEST_RESOURCES=true`;
8. restores the direct Operator replica count even on failure.

No existing product CR is deleted.

## Image publication preflight

The bundle currently references:

- `ghcr.io/zdmooc/mayabank-platform-operator:v0.1.0`;
- `ghcr.io/zdmooc/mayabank-platform-operator:v0.2.0`;
- `ghcr.io/zdmooc/mayabank-platform-operator-bundle:v0.1.0`;
- `ghcr.io/zdmooc/mayabank-platform-operator-bundle:v0.2.0`.

OP2 fails **before cluster mutation** if these images are not pullable.

If needed, run the manual GitHub Actions workflow:

`D093 OP2 Publish Operator Images`.

## Runtime sequence

```text
CRC/OpenShift
 -> OLM Classic APIs preflight
 -> GHCR image pull preflight
 -> park direct Operator
 -> OLM install bundle v0.1.0
 -> CSV Succeeded
 -> dedicated CapabilityConsumption Reconciled
 -> bundle upgrade v0.2.0
 -> CSV v0.2.0 Succeeded
 -> delete managed ResourceQuota
 -> Operator reconstructs it
 -> delete Subscription + CSV
 -> OLM Deployment removed
 -> CRD retained
 -> CR retained
 -> managed ResourceQuota retained
 -> cleanup dedicated test resources
 -> restore direct Operator
```

## Expected markers

```text
OP2_OLM_CLASSIC_APIS=PASS
OP2_GHCR_IMAGES_PULLABLE=PASS
OP2_DIRECT_OPERATOR_PARK=PASS
OP2_OPENSHIFT_OLM_V010_INSTALL=PASS
OP2_OPENSHIFT_OLM_CONSUMER_RECONCILE=PASS
OP2_OPENSHIFT_OLM_UPGRADE=PASS
OP2_OPENSHIFT_POST_UPGRADE_RECONCILIATION=PASS
OP2_OPENSHIFT_OLM_UNINSTALL_RETAIN=PASS
OP2_OPENSHIFT_OLM_LIFECYCLE_RESULT=PASS
claim=OPENSHIFT_OLM_LIFECYCLE_PROVEN_CRC
```

## Truth boundary

Until those markers are observed on CRC/OpenShift, the current claim remains:

`KIND_OLM_LIFECYCLE_PROVEN + OPENSHIFT_OPERATOR_RUNTIME_PROVEN_CONSUMER_1`.

After a successful OP2 run the bounded additional claim becomes:

`OPENSHIFT_OLM_LIFECYCLE_PROVEN_CRC`.

This still does **not** prove multi-node OpenShift HA or production readiness.

The v0.1.0 and v0.2.0 bundle pair is an **OLM packaging lifecycle fixture** using the same underlying controller code, as documented in `docs/iterations/D093-I6C-OLM-OPENSHIFT-PACKAGING.md`. A successful replay proves package/version orchestration and post-upgrade reconciliation, not a functional Go-controller upgrade with schema/data migration.
