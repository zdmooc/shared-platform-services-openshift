package controller

import (
	"context"
	"errors"
	"fmt"
	"reflect"
	"sort"
	"strings"

	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/meta"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/client-go/tools/record"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/apiutil"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	platformv1alpha1 "github.com/zdmooc/shared-platform-services-openshift/operators/platform-onboarding-operator/api/v1alpha1"
)

const (
	FieldManager         = "mayabank-platform-operator"
	ManagedByLabel       = "platform.mayabank.example/managed-by"
	ConsumerLabel        = "platform.mayabank.example/consumer"
	ConsumptionLabel     = "platform.mayabank.example/consumption"
	ManagedByValue       = "mayabank-platform-operator"
	ConditionReady       = "Ready"
	ConditionAdoptable   = "AdoptionReady"
	ConditionDegraded    = "Degraded"
	ConditionProgressing = "Progressing"
	platformQuotaName    = "platform-quota"
	platformLimitsName   = "platform-defaults"
)

type CapabilityConsumptionReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Recorder record.EventRecorder
}

// +kubebuilder:rbac:groups=platform.mayabank.example,resources=capabilityconsumptions,verbs=get;list;watch;update;patch
// +kubebuilder:rbac:groups=platform.mayabank.example,resources=capabilityconsumptions/status,verbs=get;update;patch
// +kubebuilder:rbac:groups="",resources=namespaces;serviceaccounts;resourcequotas;limitranges;configmaps;services,verbs=get;list;watch;create;update;patch
// +kubebuilder:rbac:groups="",resources=events,verbs=create;patch
// +kubebuilder:rbac:groups=rbac.authorization.k8s.io,resources=roles;rolebindings,verbs=get;list;watch;create;update;patch
// +kubebuilder:rbac:groups=networking.k8s.io,resources=networkpolicies,verbs=get;list;watch;create;update;patch
// +kubebuilder:rbac:groups=coordination.k8s.io,resources=leases,verbs=get;list;watch;create;update;patch

func (r *CapabilityConsumptionReconciler) Reconcile(ctx context.Context, req ctrl.Request) (result ctrl.Result, err error) {
	outcome := "lookup"
	finishMetrics := startReconcileMetrics()
	defer func() {
		if err != nil && outcome == "reconciled" {
			outcome = "error"
		}
		finishMetrics(outcome)
	}()

	var cc platformv1alpha1.CapabilityConsumption
	if err = r.Get(ctx, req.NamespacedName, &cc); err != nil {
		outcome = "not_found"
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	if !cc.DeletionTimestamp.IsZero() {
		// K2 V1 deliberately retains managed resources.
		outcome = "retain_delete"
		return ctrl.Result{}, nil
	}

	if cc.Spec.Target.Namespace == "" {
		outcome = "invalid_spec"
		return ctrl.Result{}, r.setStatus(ctx, &cc, metav1.ConditionFalse, "InvalidSpec", "spec.target.namespace is required for reconciliation", nil)
	}

	policy := cc.Spec.Lifecycle.AdoptionPolicy
	if policy == "" {
		policy = platformv1alpha1.AdoptionObserve
	}

	desired := desiredObjects(&cc)
	conflicts, detectErr := r.detectConflicts(ctx, &cc, desired, policy)
	if detectErr != nil {
		outcome = "dependency_read_failed"
		return ctrl.Result{}, r.retryableFailure(ctx, &cc, "DependencyReadFailed", "dependency_read", detectErr, nil)
	}
	if len(conflicts) > 0 {
		message := strings.Join(conflicts, "; ")
		if r.Recorder != nil {
			r.Recorder.Event(&cc, corev1.EventTypeWarning, "OwnershipConflict", message)
		}
		outcome = "ownership_conflict"
		return ctrl.Result{}, r.setStatus(ctx, &cc, metav1.ConditionFalse, "OwnershipConflict", message, nil)
	}

	if policy == platformv1alpha1.AdoptionObserve {
		if r.Recorder != nil {
			r.Recorder.Event(&cc, corev1.EventTypeNormal, "ObservationComplete", "observe mode completed without mutation")
		}
		outcome = "observe"
		return ctrl.Result{}, r.setStatus(ctx, &cc, metav1.ConditionFalse, "ObserveMode", "observation complete; explicit Manage is required before mutation", nil)
	}

	if cc.Status.ObservedGeneration != cc.Generation {
		if statusErr := r.setProgressingStatus(ctx, &cc, "Reconciling", "applying declared platform-owned baseline"); statusErr != nil {
			outcome = "status_error"
			retryableFailureTotal.WithLabelValues("status_update").Inc()
			return ctrl.Result{}, fmt.Errorf("persist progressing status: %w", statusErr)
		}
	}

	managed := make([]platformv1alpha1.ManagedResourceReference, 0, len(desired))
	for _, obj := range desired {
		if applyErr := r.apply(ctx, obj); applyErr != nil {
			outcome = "apply_failed"
			return ctrl.Result{}, r.retryableFailure(ctx, &cc, "ApplyFailed", "apply", applyErr, managed)
		}
		ref, refErr := r.resourceReference(obj)
		if refErr != nil {
			outcome = "reference_error"
			return ctrl.Result{}, r.retryableFailure(ctx, &cc, "ReferenceFailed", "reference", refErr, managed)
		}
		managed = append(managed, ref)
	}

	if r.Recorder != nil {
		r.Recorder.Event(&cc, corev1.EventTypeNormal, "Reconciled", fmt.Sprintf("reconciled %d platform-owned resources", len(managed)))
	}
	outcome = "reconciled"
	if statusErr := r.setStatus(ctx, &cc, metav1.ConditionTrue, "Reconciled", "platform-owned resources match declared intent", managed); statusErr != nil {
		outcome = "status_error"
		retryableFailureTotal.WithLabelValues("status_update").Inc()
		return ctrl.Result{}, fmt.Errorf("persist reconciled status: %w", statusErr)
	}
	return ctrl.Result{}, nil
}

func (r *CapabilityConsumptionReconciler) retryableFailure(
	ctx context.Context,
	cc *platformv1alpha1.CapabilityConsumption,
	reason string,
	stage string,
	cause error,
	managed []platformv1alpha1.ManagedResourceReference,
) error {
	retryableFailureTotal.WithLabelValues(stage).Inc()
	if r.Recorder != nil {
		r.Recorder.Event(cc, corev1.EventTypeWarning, reason, cause.Error())
	}
	statusErr := r.setStatus(ctx, cc, metav1.ConditionFalse, reason, cause.Error(), managed)
	if statusErr != nil {
		return errors.Join(cause, fmt.Errorf("persist %s status: %w", reason, statusErr))
	}
	return cause
}

func (r *CapabilityConsumptionReconciler) SetupWithManager(mgr ctrl.Manager) error {
	mapper := handler.EnqueueRequestsFromMapFunc(r.mapManagedResource)
	return ctrl.NewControllerManagedBy(mgr).
		For(&platformv1alpha1.CapabilityConsumption{}).
		Watches(&corev1.Namespace{}, mapper).
		Watches(&corev1.ServiceAccount{}, mapper).
		Watches(&corev1.ResourceQuota{}, mapper).
		Watches(&corev1.LimitRange{}, mapper).
		Watches(&rbacv1.Role{}, mapper).
		Watches(&rbacv1.RoleBinding{}, mapper).
		Watches(&networkingv1.NetworkPolicy{}, mapper).
		Complete(r)
}

func (r *CapabilityConsumptionReconciler) mapManagedResource(_ context.Context, obj client.Object) []reconcile.Request {
	name := obj.GetLabels()[ConsumptionLabel]
	if name == "" {
		return nil
	}
	return []reconcile.Request{{NamespacedName: client.ObjectKey{Name: name}}}
}

func (r *CapabilityConsumptionReconciler) detectConflicts(ctx context.Context, cc *platformv1alpha1.CapabilityConsumption, desired []client.Object, policy platformv1alpha1.AdoptionPolicy) ([]string, error) {
	conflicts := map[string]struct{}{}

	for _, obj := range desired {
		current := emptyObjectLike(obj)
		err := r.Get(ctx, client.ObjectKeyFromObject(obj), current)
		if apierrors.IsNotFound(err) {
			continue
		}
		if err != nil {
			return nil, err
		}
		if current.GetLabels()[ManagedByLabel] == ManagedByValue {
			consumption := current.GetLabels()[ConsumptionLabel]
			if consumption != "" && consumption != cc.Name {
				conflicts[fmt.Sprintf("%s is already managed for CapabilityConsumption/%s", objectDescription(obj), consumption)] = struct{}{}
			}
			continue
		}
		if _, isNamespace := obj.(*corev1.Namespace); isNamespace && policy == platformv1alpha1.AdoptionManage {
			// Manage is the explicit approval to add only the operator's own labels
			// to a pre-existing namespace after the product-side migration gate.
			continue
		}
		conflicts[fmt.Sprintf("%s already exists and is not platform-managed", objectDescription(obj))] = struct{}{}
	}

	namespace := cc.Spec.Target.Namespace
	if namespace != "" {
		var quotas corev1.ResourceQuotaList
		if err := r.List(ctx, &quotas, client.InNamespace(namespace)); err != nil {
			return nil, err
		}
		for i := range quotas.Items {
			item := &quotas.Items[i]
			if item.Labels[ManagedByLabel] != ManagedByValue {
				conflicts[fmt.Sprintf("ResourceQuota/%s is an existing product-owned baseline", item.Name)] = struct{}{}
			}
		}

		var limits corev1.LimitRangeList
		if err := r.List(ctx, &limits, client.InNamespace(namespace)); err != nil {
			return nil, err
		}
		for i := range limits.Items {
			item := &limits.Items[i]
			if item.Labels[ManagedByLabel] != ManagedByValue {
				conflicts[fmt.Sprintf("LimitRange/%s is an existing product-owned baseline", item.Name)] = struct{}{}
			}
		}

		for _, name := range []string{"default-deny", "allow-dns-egress"} {
			var policyObj networkingv1.NetworkPolicy
			err := r.Get(ctx, client.ObjectKey{Namespace: namespace, Name: name}, &policyObj)
			if apierrors.IsNotFound(err) {
				continue
			}
			if err != nil {
				return nil, err
			}
			if policyObj.Labels[ManagedByLabel] == ManagedByValue {
				continue
			}
			if policy == platformv1alpha1.AdoptionManage {
				// Brownfield handoff bridge: in Manage mode the explicit approval allows
				// the Operator to create its differently named platform baseline first.
				// The legacy product policy can then be removed from product Git and
				// from the cluster without a network-policy-open window.
				continue
			}
			conflicts[fmt.Sprintf("NetworkPolicy/%s is an existing product-owned baseline", name)] = struct{}{}
		}
	}

	out := make([]string, 0, len(conflicts))
	for conflict := range conflicts {
		out = append(out, conflict)
	}
	sort.Strings(out)
	return out, nil
}

func (r *CapabilityConsumptionReconciler) apply(ctx context.Context, obj client.Object) error {
	gvk, err := apiutil.GVKForObject(obj, r.Scheme)
	if err != nil {
		return err
	}
	raw, err := runtime.DefaultUnstructuredConverter.ToUnstructured(obj)
	if err != nil {
		return err
	}
	u := &unstructured.Unstructured{Object: raw}
	u.SetGroupVersionKind(gvk)
	config := client.ApplyConfigurationFromUnstructured(u)
	options := &client.ApplyOptions{FieldManager: FieldManager}

	// Normal server-side apply is the default for every resource, including
	// previously unowned/brownfield objects. Never use ForceOwnership broadly.
	err = r.Apply(ctx, config, options)
	if err == nil || !apierrors.IsConflict(err) {
		return err
	}

	// A user-driven quota storage drift via a merge patch can acquire
	// f:requests.storage under kubectl-patch. Reclaim this one controlled
	// field only after proving that this exact ResourceQuota already belongs
	// to the same CapabilityConsumption. Do not force any other resource or
	// a different quota field (e.g. requests.cpu).
	desiredQuota, ok := obj.(*corev1.ResourceQuota)
	if !ok || desiredQuota.Name != platformQuotaName || desiredQuota.GetNamespace() == "" {
		return err
	}
	expectedConsumption := desiredQuota.Labels[ConsumptionLabel]
	if expectedConsumption == "" || desiredQuota.Labels[ManagedByLabel] != ManagedByValue {
		return err
	}
	currentQuota := &corev1.ResourceQuota{}
	if readErr := r.Get(ctx, client.ObjectKeyFromObject(desiredQuota), currentQuota); readErr != nil {
		return errors.Join(err, fmt.Errorf("read quota before narrowly scoped SSA ownership recovery: %w", readErr))
	}
	if currentQuota.Labels[ManagedByLabel] != ManagedByValue ||
		currentQuota.Labels[ConsumptionLabel] != expectedConsumption ||
		currentQuota.Labels[ConsumerLabel] != desiredQuota.Labels[ConsumerLabel] {
		return err
	}
	if !quotaStorageIsOnlyHardLimitDrift(desiredQuota.Spec.Hard, currentQuota.Spec.Hard) {
		// Force applies the full quota spec, not an individual hard-limit key.
		// Do not force if CPU/memory/PVCs/other dimensions differ alongside
		// storage, as doing so would seize unrelated ownership.
		return err
	}

	// Force applies the complete declared quota baseline; it is safe only
	// within the already-claimed, exact consumer-owned platform quota and
	// only following an observed SSA conflict on a storage-only value drift.
	if forceErr := r.Apply(ctx, config, options, client.ForceOwnership); forceErr != nil {
		return errors.Join(err, fmt.Errorf("recover SSA-owned requests.storage on platform quota: %w", forceErr))
	}
	return nil
}

// quotaStorageIsOnlyHardLimitDrift deliberately refuses to ForceOwnership
// when *any* other quota hard limit changed or a new/unexpected limit exists.
func quotaStorageIsOnlyHardLimitDrift(desired, current corev1.ResourceList) bool {
	if len(desired) != len(current) {
		return false
	}
	storageDrift := false
	for name, expected := range desired {
		actual, exists := current[name]
		if !exists {
			return false
		}
		if name == corev1.ResourceRequestsStorage {
			storageDrift = expected.Cmp(actual) != 0
		} else if expected.Cmp(actual) != 0 {
			return false
		}
	}
	return storageDrift
}

func (r *CapabilityConsumptionReconciler) resourceReference(obj client.Object) (platformv1alpha1.ManagedResourceReference, error) {
	gvk, err := apiutil.GVKForObject(obj, r.Scheme)
	if err != nil {
		return platformv1alpha1.ManagedResourceReference{}, err
	}
	return platformv1alpha1.ManagedResourceReference{
		APIVersion: gvk.GroupVersion().String(),
		Kind:       gvk.Kind,
		Namespace:  obj.GetNamespace(),
		Name:       obj.GetName(),
	}, nil
}

func (r *CapabilityConsumptionReconciler) setProgressingStatus(ctx context.Context, cc *platformv1alpha1.CapabilityConsumption, reason, message string) error {
	before := cc.DeepCopy().Status
	meta.SetStatusCondition(&cc.Status.Conditions, metav1.Condition{
		Type:               ConditionProgressing,
		Status:             metav1.ConditionTrue,
		ObservedGeneration: cc.Generation,
		Reason:             reason,
		Message:            message,
	})
	meta.SetStatusCondition(&cc.Status.Conditions, metav1.Condition{
		Type:               ConditionDegraded,
		Status:             metav1.ConditionFalse,
		ObservedGeneration: cc.Generation,
		Reason:             "Reconciling",
		Message:            "no reconcile error observed",
	})
	if reflect.DeepEqual(before, cc.Status) {
		return nil
	}
	return r.Status().Update(ctx, cc)
}

func (r *CapabilityConsumptionReconciler) setStatus(ctx context.Context, cc *platformv1alpha1.CapabilityConsumption, status metav1.ConditionStatus, reason, message string, managed []platformv1alpha1.ManagedResourceReference) error {
	before := cc.DeepCopy().Status
	cc.Status.ObservedGeneration = cc.Generation
	if managed != nil {
		cc.Status.ManagedResources = managed
	}
	meta.SetStatusCondition(&cc.Status.Conditions, metav1.Condition{
		Type:               ConditionReady,
		Status:             status,
		ObservedGeneration: cc.Generation,
		Reason:             reason,
		Message:            message,
	})

	progressReason := "Stable"
	progressMessage := "reconciliation is not in progress"
	degradedStatus := metav1.ConditionFalse
	degradedReason := "Healthy"
	degradedMessage := "no reconcile error observed"

	switch reason {
	case "InvalidSpec", "ApplyFailed", "DependencyReadFailed", "ReferenceFailed":
		degradedStatus = metav1.ConditionTrue
		degradedReason = reason
		degradedMessage = message
	case "OwnershipConflict":
		progressReason = "Blocked"
		progressMessage = "reconciliation is blocked by the non-destructive ownership guardrail"
		degradedReason = "OwnershipProtected"
		degradedMessage = "existing product-owned resources were left unchanged"
		meta.SetStatusCondition(&cc.Status.Conditions, metav1.Condition{
			Type:               ConditionAdoptable,
			Status:             metav1.ConditionFalse,
			ObservedGeneration: cc.Generation,
			Reason:             reason,
			Message:            message,
		})
	case "ObserveMode":
		degradedReason = "Observed"
		degradedMessage = "observe mode completed without mutation"
		meta.SetStatusCondition(&cc.Status.Conditions, metav1.Condition{
			Type:               ConditionAdoptable,
			Status:             metav1.ConditionTrue,
			ObservedGeneration: cc.Generation,
			Reason:             "NoOwnershipConflict",
			Message:            "no ownership conflicts detected; change adoptionPolicy to Manage after explicit approval",
		})
	case "Reconciled":
		meta.SetStatusCondition(&cc.Status.Conditions, metav1.Condition{
			Type:               ConditionAdoptable,
			Status:             metav1.ConditionTrue,
			ObservedGeneration: cc.Generation,
			Reason:             "Managed",
			Message:            "platform-owned resources are managed by the operator",
		})
	}

	meta.SetStatusCondition(&cc.Status.Conditions, metav1.Condition{
		Type:               ConditionProgressing,
		Status:             metav1.ConditionFalse,
		ObservedGeneration: cc.Generation,
		Reason:             progressReason,
		Message:            progressMessage,
	})
	meta.SetStatusCondition(&cc.Status.Conditions, metav1.Condition{
		Type:               ConditionDegraded,
		Status:             degradedStatus,
		ObservedGeneration: cc.Generation,
		Reason:             degradedReason,
		Message:            degradedMessage,
	})

	if reflect.DeepEqual(before, cc.Status) {
		return nil
	}
	return r.Status().Update(ctx, cc)
}

func desiredObjects(cc *platformv1alpha1.CapabilityConsumption) []client.Object {
	namespace := cc.Spec.Target.Namespace
	labels := managedLabels(cc)
	profile := quotaProfile(cc.Spec.Resources.Profile)

	protocolTCP := corev1.ProtocolTCP
	protocolUDP := corev1.ProtocolUDP
	dnsPort := intstr.FromInt32(53)
	httpsPort := intstr.FromInt32(443)
	keycloakPort := intstr.FromInt32(8080)
	otlpGRPC := intstr.FromInt32(4317)
	otlpHTTP := intstr.FromInt32(4318)

	objects := []client.Object{
		&corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: namespace, Labels: labels}},
		&corev1.ServiceAccount{ObjectMeta: metav1.ObjectMeta{Name: "platform-consumer", Namespace: namespace, Labels: labels}},
		&rbacv1.Role{
			ObjectMeta: metav1.ObjectMeta{Name: "platform-consumer-read", Namespace: namespace, Labels: labels},
			Rules:      []rbacv1.PolicyRule{{APIGroups: []string{""}, Resources: []string{"services", "configmaps"}, Verbs: []string{"get", "list", "watch"}}},
		},
		&rbacv1.RoleBinding{
			ObjectMeta: metav1.ObjectMeta{Name: "platform-consumer-read", Namespace: namespace, Labels: labels},
			RoleRef:    rbacv1.RoleRef{APIGroup: rbacv1.GroupName, Kind: "Role", Name: "platform-consumer-read"},
			Subjects:   []rbacv1.Subject{{Kind: "ServiceAccount", Name: "platform-consumer", Namespace: namespace}},
		},
		&corev1.ResourceQuota{
			ObjectMeta: metav1.ObjectMeta{Name: platformQuotaName, Namespace: namespace, Labels: labels},
			Spec:       corev1.ResourceQuotaSpec{Hard: profile},
		},
		&corev1.LimitRange{
			ObjectMeta: metav1.ObjectMeta{Name: platformLimitsName, Namespace: namespace, Labels: labels},
			Spec: corev1.LimitRangeSpec{Limits: []corev1.LimitRangeItem{{
				Type: corev1.LimitTypeContainer,
				DefaultRequest: corev1.ResourceList{
					corev1.ResourceCPU:    resource.MustParse("50m"),
					corev1.ResourceMemory: resource.MustParse("64Mi"),
				},
				Default: corev1.ResourceList{
					corev1.ResourceCPU:    resource.MustParse("1"),
					corev1.ResourceMemory: resource.MustParse("1Gi"),
				},
			}}},
		},
		&networkingv1.NetworkPolicy{
			ObjectMeta: metav1.ObjectMeta{Name: "platform-default-deny", Namespace: namespace, Labels: labels},
			Spec: networkingv1.NetworkPolicySpec{
				PodSelector: metav1.LabelSelector{},
				PolicyTypes: []networkingv1.PolicyType{networkingv1.PolicyTypeIngress, networkingv1.PolicyTypeEgress},
			},
		},
		&networkingv1.NetworkPolicy{
			ObjectMeta: metav1.ObjectMeta{Name: "platform-dns-egress", Namespace: namespace, Labels: labels},
			Spec: networkingv1.NetworkPolicySpec{
				PodSelector: metav1.LabelSelector{},
				PolicyTypes: []networkingv1.PolicyType{networkingv1.PolicyTypeEgress},
				Egress: []networkingv1.NetworkPolicyEgressRule{{Ports: []networkingv1.NetworkPolicyPort{
					{Protocol: &protocolUDP, Port: &dnsPort},
					{Protocol: &protocolTCP, Port: &dnsPort},
				}}},
			},
		},
	}

	if cc.Spec.Identity.Mode == platformv1alpha1.ConsumeShared {
		objects = append(objects, &networkingv1.NetworkPolicy{
			ObjectMeta: metav1.ObjectMeta{Name: "platform-shared-oidc-egress", Namespace: namespace, Labels: labels},
			Spec: networkingv1.NetworkPolicySpec{
				PodSelector: metav1.LabelSelector{},
				PolicyTypes: []networkingv1.PolicyType{networkingv1.PolicyTypeEgress},
				Egress: []networkingv1.NetworkPolicyEgressRule{{
					To: []networkingv1.NetworkPolicyPeer{{NamespaceSelector: &metav1.LabelSelector{MatchLabels: map[string]string{
						"platform.mayabank.example/capability": "identity",
					}}}},
					Ports: []networkingv1.NetworkPolicyPort{
						{Protocol: &protocolTCP, Port: &httpsPort},
						{Protocol: &protocolTCP, Port: &keycloakPort},
					},
				}},
			},
		})
	}

	if cc.Spec.Observability.Mode == platformv1alpha1.ConsumeShared {
		objects = append(objects, &networkingv1.NetworkPolicy{
			ObjectMeta: metav1.ObjectMeta{Name: "platform-shared-otel-egress", Namespace: namespace, Labels: labels},
			Spec: networkingv1.NetworkPolicySpec{
				PodSelector: metav1.LabelSelector{},
				PolicyTypes: []networkingv1.PolicyType{networkingv1.PolicyTypeEgress},
				Egress: []networkingv1.NetworkPolicyEgressRule{{
					To: []networkingv1.NetworkPolicyPeer{{NamespaceSelector: &metav1.LabelSelector{MatchLabels: map[string]string{
						"platform.mayabank.example/capability": "observability",
					}}}},
					Ports: []networkingv1.NetworkPolicyPort{
						{Protocol: &protocolTCP, Port: &otlpGRPC},
						{Protocol: &protocolTCP, Port: &otlpHTTP},
					},
				}},
			},
		})
	}

	return objects
}

func managedLabels(cc *platformv1alpha1.CapabilityConsumption) map[string]string {
	consumer := cc.Spec.Consumer.Name
	if consumer == "" {
		consumer = cc.Name
	}
	return map[string]string{
		ManagedByLabel:   ManagedByValue,
		ConsumerLabel:    consumer,
		ConsumptionLabel: cc.Name,
	}
}

func quotaProfile(name string) corev1.ResourceList {
	switch name {
	case "small":
		return corev1.ResourceList{
			corev1.ResourceRequestsCPU:            resource.MustParse("2"),
			corev1.ResourceRequestsMemory:         resource.MustParse("4Gi"),
			corev1.ResourceLimitsCPU:              resource.MustParse("4"),
			corev1.ResourceLimitsMemory:           resource.MustParse("8Gi"),
			corev1.ResourcePersistentVolumeClaims: resource.MustParse("4"),
			corev1.ResourceRequestsStorage:        resource.MustParse("10Gi"),
		}
	case "ai-medium":
		return corev1.ResourceList{
			corev1.ResourceRequestsCPU:            resource.MustParse("6"),
			corev1.ResourceRequestsMemory:         resource.MustParse("10Gi"),
			corev1.ResourceLimitsCPU:              resource.MustParse("16"),
			corev1.ResourceLimitsMemory:           resource.MustParse("24Gi"),
			corev1.ResourcePersistentVolumeClaims: resource.MustParse("8"),
			corev1.ResourceRequestsStorage:        resource.MustParse("20Gi"),
		}
	case "payments-medium":
		return corev1.ResourceList{
			corev1.ResourceRequestsCPU:            resource.MustParse("4"),
			corev1.ResourceRequestsMemory:         resource.MustParse("8Gi"),
			corev1.ResourceLimitsCPU:              resource.MustParse("12"),
			corev1.ResourceLimitsMemory:           resource.MustParse("16Gi"),
			corev1.ResourcePersistentVolumeClaims: resource.MustParse("6"),
			corev1.ResourceRequestsStorage:        resource.MustParse("20Gi"),
		}
	default:
		return corev1.ResourceList{
			corev1.ResourceRequestsCPU:            resource.MustParse("4"),
			corev1.ResourceRequestsMemory:         resource.MustParse("8Gi"),
			corev1.ResourceLimitsCPU:              resource.MustParse("8"),
			corev1.ResourceLimitsMemory:           resource.MustParse("16Gi"),
			corev1.ResourcePersistentVolumeClaims: resource.MustParse("6"),
			corev1.ResourceRequestsStorage:        resource.MustParse("20Gi"),
		}
	}
}

func emptyObjectLike(obj client.Object) client.Object {
	switch obj.(type) {
	case *corev1.Namespace:
		return &corev1.Namespace{}
	case *corev1.ServiceAccount:
		return &corev1.ServiceAccount{}
	case *corev1.ResourceQuota:
		return &corev1.ResourceQuota{}
	case *corev1.LimitRange:
		return &corev1.LimitRange{}
	case *rbacv1.Role:
		return &rbacv1.Role{}
	case *rbacv1.RoleBinding:
		return &rbacv1.RoleBinding{}
	case *networkingv1.NetworkPolicy:
		return &networkingv1.NetworkPolicy{}
	default:
		panic(fmt.Sprintf("unsupported managed object type %T", obj))
	}
}

func objectDescription(obj client.Object) string {
	switch obj.(type) {
	case *corev1.Namespace:
		return "Namespace/" + obj.GetName()
	case *corev1.ServiceAccount:
		return "ServiceAccount/" + obj.GetName()
	case *corev1.ResourceQuota:
		return "ResourceQuota/" + obj.GetName()
	case *corev1.LimitRange:
		return "LimitRange/" + obj.GetName()
	case *rbacv1.Role:
		return "Role/" + obj.GetName()
	case *rbacv1.RoleBinding:
		return "RoleBinding/" + obj.GetName()
	case *networkingv1.NetworkPolicy:
		return "NetworkPolicy/" + obj.GetName()
	default:
		return fmt.Sprintf("%T/%s", obj, obj.GetName())
	}
}
