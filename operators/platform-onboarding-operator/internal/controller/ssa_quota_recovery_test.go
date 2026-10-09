package controller

import (
	"context"
	"strings"
	"testing"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"

	platformv1alpha1 "github.com/zdmooc/shared-platform-services-openshift/operators/platform-onboarding-operator/api/v1alpha1"
)

// Reproduces the observed D-093 CRC pattern:
// Platform Operator Apply -> kubectl-patch Update 20Gi->99Gi -> Operator
// retries ordinary Apply, then uses restricted ownership recovery.
func TestManagedQuotaStorageConflictRecoversViaNarrowForce(t *testing.T) {
	ctx := context.Background()
	ns := "d093-ssa-storage-recovery"
	cc := newConsumption("d093-ssa-storage-cr", "instant-payments", ns, platformv1alpha1.AdoptionManage)
	cc.Spec.Resources.Profile = "payments-medium"
	mustCreate(t, ctx, cc)

	req := ctrl.Request{NamespacedName: client.ObjectKey{Name: cc.Name}}
	r := reconciler()
	if _, err := r.Reconcile(ctx, req); err != nil {
		t.Fatalf("initial managed resource reconcile: %v", err)
	}

	quota := &corev1.ResourceQuota{}
	key := client.ObjectKey{Namespace: ns, Name: platformQuotaName}
	if err := testClient.Get(ctx, key, quota); err != nil {
		t.Fatalf("get initial quota: %v", err)
	}
	original := quota.Spec.Hard[corev1.ResourceRequestsStorage]
	if original.String() != "20Gi" {
		t.Fatalf("expected 20Gi before drift, got %s", original.String())
	}

	if err := testClient.Patch(ctx, quota, client.RawPatch(types.MergePatchType, []byte(
		`{"spec":{"hard":{"requests.storage":"99Gi"}}}`,
	)), client.FieldOwner("kubectl-patch")); err != nil {
		t.Fatalf("inject competing storage manager: %v", err)
	}
	if err := testClient.Get(ctx, key, quota); err != nil {
		t.Fatalf("get drifted quota: %v", err)
	}
	drifted := quota.Spec.Hard[corev1.ResourceRequestsStorage]
	if drifted.String() != "99Gi" {
		t.Fatalf("expected 99Gi after patch, got %s", drifted.String())
	}

	// This is the real apiserver/SSA path (envtest), not a mocked conflict.
	if _, err := r.Reconcile(ctx, req); err != nil {
		t.Fatalf("reconcile must recover already-owned quota drift: %v", err)
	}
	if err := testClient.Get(ctx, key, quota); err != nil {
		t.Fatalf("get healed quota: %v", err)
	}
	healed := quota.Spec.Hard[corev1.ResourceRequestsStorage]
	if healed.String() != "20Gi" {
		t.Fatalf("operator did not restore storage automatically, actual=%s", healed.String())
	}
	if quota.Labels[ManagedByLabel] != ManagedByValue || quota.Labels[ConsumptionLabel] != cc.Name {
		t.Fatalf("quota ownership was lost: %#v", quota.Labels)
	}

	status := &platformv1alpha1.CapabilityConsumption{}
	if err := testClient.Get(ctx, client.ObjectKey{Name: cc.Name}, status); err != nil {
		t.Fatalf("get recovered CR: %v", err)
	}
	ready := meta.FindStatusCondition(status.Status.Conditions, ConditionReady)
	if ready == nil || ready.Status != metav1.ConditionTrue || ready.Reason != "Reconciled" {
		t.Fatalf("expected Ready=True/Reconciled after storage drift, got %#v", ready)
	}
}

// The exception is intentionally limited to requests.storage. Conflicts over
// other quota dimensions remain observable failures and must not be seized.
func TestManagedQuotaCPUConflictDoesNotForceOwnership(t *testing.T) {
	ctx := context.Background()
	ns := "d093-ssa-cpu-guard"
	cc := newConsumption("d093-ssa-cpu-cr", "instant-payments", ns, platformv1alpha1.AdoptionManage)
	cc.Spec.Resources.Profile = "payments-medium"
	mustCreate(t, ctx, cc)

	req := ctrl.Request{NamespacedName: client.ObjectKey{Name: cc.Name}}
	r := reconciler()
	if _, err := r.Reconcile(ctx, req); err != nil {
		t.Fatalf("initial reconcile: %v", err)
	}

	quota := &corev1.ResourceQuota{}
	key := client.ObjectKey{Namespace: ns, Name: platformQuotaName}
	if err := testClient.Get(ctx, key, quota); err != nil {
		t.Fatalf("get quota: %v", err)
	}
	if err := testClient.Patch(ctx, quota, client.RawPatch(types.MergePatchType,
		[]byte(`{"spec":{"hard":{"requests.cpu":"3"}}}`)),
		client.FieldOwner("kubectl-patch")); err != nil {
		t.Fatalf("inject competing CPU manager: %v", err)
	}

	if _, err := r.Reconcile(ctx, req); err == nil {
		t.Fatal("CPU-only SSA field conflict must not be ForceOwned")
	} else if !strings.Contains(strings.ToLower(err.Error()), "conflict") {
		t.Fatalf("expected explicit SSA conflict, got %v", err)
	}

	if err := testClient.Get(ctx, key, quota); err != nil {
		t.Fatalf("get quota after refused CPU takeover: %v", err)
	}
	cpu := quota.Spec.Hard[corev1.ResourceRequestsCPU]
	if cpu.String() != "3" {
		t.Fatalf("unexpected CPU ownership transfer, got %s", cpu.String())
	}
	storage := quota.Spec.Hard[corev1.ResourceRequestsStorage]
	if storage.String() != "20Gi" {
		t.Fatalf("storage baseline changed unexpectedly to %s", storage.String())
	}

	status := &platformv1alpha1.CapabilityConsumption{}
	if err := testClient.Get(ctx, client.ObjectKey{Name: cc.Name}, status); err != nil {
		t.Fatalf("get CR status: %v", err)
	}
	ready := meta.FindStatusCondition(status.Status.Conditions, ConditionReady)
	if ready == nil || ready.Status != metav1.ConditionFalse || ready.Reason != "ApplyFailed" {
		t.Fatalf("expected explicit ApplyFailed, got %#v", ready)
	}
}

// An external quota with the platform name is *not* adopted, even if its
// storage limit conflicts with the desired value and the CR is in Manage.
func TestUnownedQuotaStorageConflictRemainsProtected(t *testing.T) {
	ctx := context.Background()
	ns := "d093-ssa-unowned-guard"
	mustCreate(t, ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: ns}})
	mustCreate(t, ctx, &corev1.ResourceQuota{
		ObjectMeta: metav1.ObjectMeta{Name: platformQuotaName, Namespace: ns},
		Spec: corev1.ResourceQuotaSpec{Hard: corev1.ResourceList{
			corev1.ResourceRequestsStorage: resource.MustParse("99Gi"),
		}},
	})

	cc := newConsumption("d093-ssa-unowned-cr", "unowned", ns, platformv1alpha1.AdoptionManage)
	cc.Spec.Resources.Profile = "payments-medium"
	mustCreate(t, ctx, cc)

	if _, err := reconciler().Reconcile(ctx, ctrl.Request{NamespacedName: client.ObjectKey{Name: cc.Name}}); err != nil {
		t.Fatalf("ownership guard returns a recorded condition, got error %v", err)
	}
	quota := &corev1.ResourceQuota{}
	if err := testClient.Get(ctx, client.ObjectKey{Namespace: ns, Name: platformQuotaName}, quota); err != nil {
		t.Fatalf("get unowned quota: %v", err)
	}
	storage := quota.Spec.Hard[corev1.ResourceRequestsStorage]
	if storage.String() != "99Gi" {
		t.Fatalf("reconciler modified an unowned quota: %s", storage.String())
	}
	status := &platformv1alpha1.CapabilityConsumption{}
	if err := testClient.Get(ctx, client.ObjectKey{Name: cc.Name}, status); err != nil {
		t.Fatalf("get guarded CR status: %v", err)
	}
	ready := meta.FindStatusCondition(status.Status.Conditions, ConditionReady)
	if ready == nil || ready.Reason != "OwnershipConflict" {
		t.Fatalf("expected OwnershipConflict, got %#v", ready)
	}
}
