package v1alpha1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

// CapabilityMode expresses ownership/consumption intent without leaking implementation details.
// +kubebuilder:validation:Enum=CONSUME_SHARED;DEDICATED_FOR_TEST;SPECIALIZED_PLATFORM;PRODUCT_OWNED;REFERENCE_ONLY
type CapabilityMode string

const (
	ConsumeShared       CapabilityMode = "CONSUME_SHARED"
	DedicatedForTest    CapabilityMode = "DEDICATED_FOR_TEST"
	SpecializedPlatform CapabilityMode = "SPECIALIZED_PLATFORM"
	ProductOwned        CapabilityMode = "PRODUCT_OWNED"
	ReferenceOnly       CapabilityMode = "REFERENCE_ONLY"
)

// AdoptionPolicy controls whether the operator only observes or actively manages platform-owned resources.
// +kubebuilder:validation:Enum=Observe;Manage
type AdoptionPolicy string

const (
	AdoptionObserve AdoptionPolicy = "Observe"
	AdoptionManage  AdoptionPolicy = "Manage"
)

// DeletionPolicy controls what happens to managed resources when intent is removed.
// +kubebuilder:validation:Enum=Retain
type DeletionPolicy string

const (
	DeletionRetain DeletionPolicy = "Retain"
)

type CapabilitySelection struct {
	Mode CapabilityMode `json:"mode"`
}

type ConsumerIdentity struct {
	Name        string `json:"name,omitempty"`
	Owner       string `json:"owner,omitempty"`
	Environment string `json:"environment,omitempty"`
}

type TargetSpec struct {
	// +kubebuilder:validation:MinLength=1
	Namespace string `json:"namespace,omitempty"`
}

type ResourceProfileSpec struct {
	// +kubebuilder:validation:Enum=small;medium;payments-medium;ai-medium
	Profile string `json:"profile,omitempty"`
}

type NetworkProfileSpec struct {
	// +kubebuilder:validation:Enum=restricted
	Profile string `json:"profile,omitempty"`
}

type GitOpsSpec struct {
	Repository string `json:"repository,omitempty"`
	Revision   string `json:"revision,omitempty"`
	Path       string `json:"path,omitempty"`
}

type LifecycleSpec struct {
	// +kubebuilder:default=Observe
	AdoptionPolicy AdoptionPolicy `json:"adoptionPolicy,omitempty"`
	// +kubebuilder:default=Retain
	DeletionPolicy DeletionPolicy `json:"deletionPolicy,omitempty"`
}

type ExternalPlatformSpec struct {
	Mode     CapabilityMode `json:"mode"`
	Owner    string         `json:"owner,omitempty"`
	ExitGate string         `json:"exitGate,omitempty"`
}

// CapabilityConsumptionSpec is intent only. Product workloads remain in product Git.
type CapabilityConsumptionSpec struct {
	Consumer ConsumerIdentity `json:"consumer,omitempty"`
	Target   TargetSpec       `json:"target,omitempty"`

	Identity      CapabilitySelection `json:"identity"`
	Observability CapabilitySelection `json:"observability"`
	Secrets       CapabilitySelection `json:"secrets"`
	GitOps        CapabilitySelection `json:"gitops"`
	Quality       CapabilitySelection `json:"quality"`
	Eventing      CapabilitySelection `json:"eventing"`
	Database      CapabilitySelection `json:"database"`
	ObjectStorage CapabilitySelection `json:"objectStorage"`

	Resources ResourceProfileSpec `json:"resources,omitempty"`
	Network   NetworkProfileSpec  `json:"network,omitempty"`
	GitSource GitOpsSpec          `json:"gitSource,omitempty"`
	Lifecycle LifecycleSpec       `json:"lifecycle,omitempty"`

	ExternalPlatforms map[string]ExternalPlatformSpec `json:"externalPlatforms,omitempty"`
	OwnedCapabilities []string                        `json:"ownedCapabilities,omitempty"`
}

type ManagedResourceReference struct {
	APIVersion string `json:"apiVersion,omitempty"`
	Kind       string `json:"kind,omitempty"`
	Namespace  string `json:"namespace,omitempty"`
	Name       string `json:"name,omitempty"`
}

// CapabilityConsumptionStatus reports reconciliation without promoting runtime evidence beyond what was observed.
type CapabilityConsumptionStatus struct {
	ObservedGeneration int64                      `json:"observedGeneration,omitempty"`
	Conditions         []metav1.Condition         `json:"conditions,omitempty"`
	ManagedResources   []ManagedResourceReference `json:"managedResources,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:scope=Cluster,shortName=capcons
// +kubebuilder:printcolumn:name="Consumer",type=string,JSONPath=`.spec.consumer.name`
// +kubebuilder:printcolumn:name="Environment",type=string,JSONPath=`.spec.consumer.environment`
// +kubebuilder:printcolumn:name="Namespace",type=string,JSONPath=`.spec.target.namespace`
// +kubebuilder:printcolumn:name="Adoption",type=string,JSONPath=`.spec.lifecycle.adoptionPolicy`
// +kubebuilder:printcolumn:name="Ready",type=string,JSONPath=`.status.conditions[?(@.type=="Ready")].status`
type CapabilityConsumption struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   CapabilityConsumptionSpec   `json:"spec,omitempty"`
	Status CapabilityConsumptionStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true
type CapabilityConsumptionList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []CapabilityConsumption `json:"items"`
}

func init() {
	SchemeBuilder.Register(&CapabilityConsumption{}, &CapabilityConsumptionList{})
}
