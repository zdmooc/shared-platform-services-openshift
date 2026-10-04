package controller

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	clientgoscheme "k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/tools/record"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/envtest"

	platformv1alpha1 "github.com/zdmooc/shared-platform-services-openshift/operators/platform-onboarding-operator/api/v1alpha1"
)

var (
	testEnv    *envtest.Environment
	testClient client.Client
	testScheme *runtime.Scheme
)

func TestMain(m *testing.M) {
	testScheme = runtime.NewScheme()
	if err := clientgoscheme.AddToScheme(testScheme); err != nil {
		panic(err)
	}
	if err := platformv1alpha1.AddToScheme(testScheme); err != nil {
		panic(err)
	}

	testEnv = &envtest.Environment{
		CRDDirectoryPaths:     []string{filepath.Join("..", "..", "config", "crd", "bases")},
		ErrorIfCRDPathMissing: true,
	}
	cfg, err := testEnv.Start()
	if err != nil {
		panic(err)
	}
	testClient, err = client.New(cfg, client.Options{Scheme: testScheme})
	if err != nil {
		panic(err)
	}

	code := m.Run()
	if err := testEnv.Stop(); err != nil {
		panic(err)
	}
	os.Exit(code)
}

func TestObserveReportsBrownfieldOwnershipConflictsWithoutMutation(t *testing.T) {
	ctx := context.Background()
	ns := "tradeops-brownfield-i3"

	mustCreate(t, ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: ns}})
	mustCreate(t, ctx, &corev1.ResourceQuota{
		ObjectMeta: metav1.ObjectMeta{Name: "tradeops-runtime", Namespace: ns},
		Spec: corev1.ResourceQuotaSpec{Hard: corev1.ResourceList{
			corev1.ResourceRequestsCPU: resource.MustParse("6"),
		}},
	})
	mustCreate(t, ctx, &corev1.LimitRange{ObjectMeta: metav1.ObjectMeta{Name: "tradeops-defaults", Namespace: ns}})
	mustCreate(t, ctx, &networkingv1.NetworkPolicy{ObjectMeta: metav1.ObjectMeta{Name: "default-deny", Namespace: ns}})

	cc := newConsumption("tradeops-observe-i3", "tradeops", ns, platformv1alpha1.AdoptionObserve)
	mustCreate(t, ctx, cc)

	r := reconciler()
	if _, err := r.Reconcile(ctx, ctrl.Request{NamespacedName: client.ObjectKey{Name: cc.Name}}); err != nil {
		t.Fatalf("reconcile observe: %v", err)
	}

	got := &platformv1alpha1.CapabilityConsumption{}
	if err := testClient.Get(ctx, client.ObjectKey{Name: cc.Name}, got); err != nil {
		t.Fatalf("get status: %v", err)
	}
	ready := meta.FindStatusCondition(got.Status.Conditions, ConditionReady)
	if ready == nil || ready.Status != metav1.ConditionFalse || ready.Reason != "OwnershipConflict" {
		t.Fatalf("expected OwnershipConflict, got %#v", ready)
	}
	if !strings.Contains(ready.Message, "ResourceQuota/tradeops-runtime") {
		t.Fatalf("expected quota conflict in %q", ready.Message)
	}

	var platformQuota corev1.ResourceQuota
	err := testClient.Get(ctx, client.ObjectKey{Namespace: ns, Name: platformQuotaName}, &platformQuota)
	if err == nil {
		t.Fatalf("observe mode must not create %s", platformQuotaName)
	}
}

func TestManageCreatesPlatformOwnedBaselineAndIsIdempotent(t *testing.T) {
	ctx := context.Background()
	ns := "instant-payments-greenfield-i3"
	cc := newConsumption("instant-payments-manage-i3", "instant-payments", ns, platformv1alpha1.AdoptionManage)
	mustCreate(t, ctx, cc)

	r := reconciler()
	req := ctrl.Request{NamespacedName: client.ObjectKey{Name: cc.Name}}
	if _, err := r.Reconcile(ctx, req); err != nil {
		t.Fatalf("first reconcile: %v", err)
	}
	if _, err := r.Reconcile(ctx, req); err != nil {
		t.Fatalf("second reconcile/idempotence: %v", err)
	}

	var namespace corev1.Namespace
	if err := testClient.Get(ctx, client.ObjectKey{Name: ns}, &namespace); err != nil {
		t.Fatalf("namespace not created: %v", err)
	}
	if namespace.Labels[ManagedByLabel] != ManagedByValue {
		t.Fatalf("namespace missing managed-by label: %#v", namespace.Labels)
	}

	var quota corev1.ResourceQuota
	if err := testClient.Get(ctx, client.ObjectKey{Namespace: ns, Name: platformQuotaName}, &quota); err != nil {
		t.Fatalf("quota not created: %v", err)
	}
	if quota.Labels[ConsumptionLabel] != cc.Name {
		t.Fatalf("quota missing consumption label: %#v", quota.Labels)
	}

	got := &platformv1alpha1.CapabilityConsumption{}
	if err := testClient.Get(ctx, client.ObjectKey{Name: cc.Name}, got); err != nil {
		t.Fatalf("get status: %v", err)
	}
	ready := meta.FindStatusCondition(got.Status.Conditions, ConditionReady)
	if ready == nil || ready.Status != metav1.ConditionTrue || ready.Reason != "Reconciled" {
		t.Fatalf("expected Ready/Reconciled, got %#v", ready)
	}
	if len(got.Status.ManagedResources) < 8 {
		t.Fatalf("expected managed resources inventory, got %d", len(got.Status.ManagedResources))
	}
}

func TestManageRefusesUnownedPlatformNamedResource(t *testing.T) {
	ctx := context.Background()
	ns := "ownership-conflict-i3"
	mustCreate(t, ctx, &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: ns}})
	mustCreate(t, ctx, &corev1.ResourceQuota{
		ObjectMeta: metav1.ObjectMeta{Name: platformQuotaName, Namespace: ns},
		Spec: corev1.ResourceQuotaSpec{Hard: corev1.ResourceList{
			corev1.ResourceRequestsCPU: resource.MustParse("1"),
		}},
	})

	cc := newConsumption("ownership-conflict-i3", "conflict", ns, platformv1alpha1.AdoptionManage)
	mustCreate(t, ctx, cc)

	r := reconciler()
	if _, err := r.Reconcile(ctx, ctrl.Request{NamespacedName: client.ObjectKey{Name: cc.Name}}); err != nil {
		t.Fatalf("reconcile conflict: %v", err)
	}

	got := &platformv1alpha1.CapabilityConsumption{}
	if err := testClient.Get(ctx, client.ObjectKey{Name: cc.Name}, got); err != nil {
		t.Fatalf("get status: %v", err)
	}
	ready := meta.FindStatusCondition(got.Status.Conditions, ConditionReady)
	if ready == nil || ready.Reason != "OwnershipConflict" {
		t.Fatalf("expected OwnershipConflict, got %#v", ready)
	}

	var quota corev1.ResourceQuota
	if err := testClient.Get(ctx, client.ObjectKey{Namespace: ns, Name: platformQuotaName}, &quota); err != nil {
		t.Fatalf("get existing quota: %v", err)
	}
	requestsCPU := quota.Spec.Hard[corev1.ResourceRequestsCPU]
	if requestsCPU.String() != "1" {
		t.Fatalf("operator overwrote unowned quota: %s", requestsCPU.String())
	}
}

func TestManageRefusesNamespaceAlreadyOwnedByAnotherConsumption(t *testing.T) {
	ctx := context.Background()
	ns := "single-consumption-i3"

	first := newConsumption("first-consumption-i3", "first", ns, platformv1alpha1.AdoptionManage)
	mustCreate(t, ctx, first)
	r := reconciler()
	if _, err := r.Reconcile(ctx, ctrl.Request{NamespacedName: client.ObjectKey{Name: first.Name}}); err != nil {
		t.Fatalf("first reconcile: %v", err)
	}

	second := newConsumption("second-consumption-i3", "second", ns, platformv1alpha1.AdoptionManage)
	mustCreate(t, ctx, second)
	if _, err := r.Reconcile(ctx, ctrl.Request{NamespacedName: client.ObjectKey{Name: second.Name}}); err != nil {
		t.Fatalf("second reconcile: %v", err)
	}

	got := &platformv1alpha1.CapabilityConsumption{}
	if err := testClient.Get(ctx, client.ObjectKey{Name: second.Name}, got); err != nil {
		t.Fatalf("get second status: %v", err)
	}
	ready := meta.FindStatusCondition(got.Status.Conditions, ConditionReady)
	if ready == nil || ready.Reason != "OwnershipConflict" {
		t.Fatalf("expected OwnershipConflict for shared namespace, got %#v", ready)
	}

	var namespace corev1.Namespace
	if err := testClient.Get(ctx, client.ObjectKey{Name: ns}, &namespace); err != nil {
		t.Fatalf("get namespace: %v", err)
	}
	if namespace.Labels[ConsumptionLabel] != first.Name {
		t.Fatalf("second consumption stole namespace ownership: %#v", namespace.Labels)
	}
}

func TestDesiredObjectsHonorSharedCapabilityIntent(t *testing.T) {
	cc := newConsumption("intent-aware-i3", "intent-aware", "intent-aware-i3", platformv1alpha1.AdoptionManage)

	names := objectNames(desiredObjects(cc))
	if names["NetworkPolicy/platform-shared-oidc-egress"] || names["NetworkPolicy/platform-shared-otel-egress"] {
		t.Fatalf("shared egress policies must not exist for REFERENCE_ONLY intent: %#v", names)
	}

	cc.Spec.Identity.Mode = platformv1alpha1.ConsumeShared
	cc.Spec.Observability.Mode = platformv1alpha1.ConsumeShared
	names = objectNames(desiredObjects(cc))
	if !names["NetworkPolicy/platform-shared-oidc-egress"] || !names["NetworkPolicy/platform-shared-otel-egress"] {
		t.Fatalf("shared egress policies missing for CONSUME_SHARED intent: %#v", names)
	}
}

func objectNames(objects []client.Object) map[string]bool {
	out := map[string]bool{}
	for _, obj := range objects {
		out[objectDescription(obj)] = true
	}
	return out
}

func reconciler() *CapabilityConsumptionReconciler {
	return &CapabilityConsumptionReconciler{
		Client:   testClient,
		Scheme:   testScheme,
		Recorder: record.NewFakeRecorder(100),
	}
}

func newConsumption(name, consumer, namespace string, policy platformv1alpha1.AdoptionPolicy) *platformv1alpha1.CapabilityConsumption {
	ref := platformv1alpha1.CapabilitySelection{Mode: platformv1alpha1.ReferenceOnly}
	return &platformv1alpha1.CapabilityConsumption{
		TypeMeta: metav1.TypeMeta{APIVersion: platformv1alpha1.GroupVersion.String(), Kind: "CapabilityConsumption"},
		ObjectMeta: metav1.ObjectMeta{Name: name},
		Spec: platformv1alpha1.CapabilityConsumptionSpec{
			Consumer:      platformv1alpha1.ConsumerIdentity{Name: consumer, Owner: "test", Environment: "envtest"},
			Target:        platformv1alpha1.TargetSpec{Namespace: namespace},
			Identity:      ref,
			Observability: ref,
			Secrets:       ref,
			GitOps:        ref,
			Quality:       ref,
			Eventing:      ref,
			Database:      ref,
			ObjectStorage: ref,
			Resources:     platformv1alpha1.ResourceProfileSpec{Profile: "medium"},
			Network:       platformv1alpha1.NetworkProfileSpec{Profile: "restricted"},
			Lifecycle:     platformv1alpha1.LifecycleSpec{AdoptionPolicy: policy, DeletionPolicy: platformv1alpha1.DeletionRetain},
		},
	}
}

func mustCreate(t *testing.T, ctx context.Context, obj client.Object) {
	t.Helper()
	if err := testClient.Create(ctx, obj); err != nil {
		t.Fatalf("create %T/%s: %v", obj, obj.GetName(), err)
	}
}
