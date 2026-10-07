SHELL := /usr/bin/env bash

GO ?= go
IMG ?= ghcr.io/zdmooc/mayabank-platform-operator:dev
LOCALBIN ?= $(CURDIR)/bin
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen
SETUP_ENVTEST ?= $(LOCALBIN)/setup-envtest
CONTROLLER_TOOLS_VERSION ?= v0.20.1
ENVTEST_VERSION ?= release-0.23
ENVTEST_K8S_VERSION ?= 1.35.x!
CRD_OUTPUT ?= config/crd/bases
RBAC_OUTPUT ?= config/rbac
VERSION ?= 0.2.0
PREVIOUS_VERSION ?= 0.1.0
BUNDLE_IMG ?= ghcr.io/zdmooc/mayabank-platform-operator-bundle:v$(VERSION)
PREVIOUS_BUNDLE_IMG ?= ghcr.io/zdmooc/mayabank-platform-operator-bundle:v$(PREVIOUS_VERSION)
CATALOG_IMG ?= ghcr.io/zdmooc/mayabank-platform-operator-catalog:v$(VERSION)
OPERATOR_SDK ?= operator-sdk
OPM_IMAGE ?= quay.io/operator-framework/opm:v1.74.0

.PHONY: all fmt vet test generate manifests verify build docker-build controller-gen envtest bundle-validate bundle-build bundle-previous-build catalog-validate catalog-build clean

all: verify build

fmt:
	$(GO) fmt ./...

vet:
	$(GO) vet ./...

test: envtest
	KUBEBUILDER_ASSETS="$$($(SETUP_ENVTEST) use -p path $(ENVTEST_K8S_VERSION))" $(GO) test ./... -count=1

generate: controller-gen
	$(CONTROLLER_GEN) object paths="./..."

manifests: controller-gen
	$(CONTROLLER_GEN) crd rbac:roleName=mayabank-platform-operator paths="./..." \
		output:crd:artifacts:config=$(CRD_OUTPUT) \
		output:rbac:artifacts:config=$(RBAC_OUTPUT)

verify: fmt vet test

build:
	$(GO) build -trimpath -o bin/manager ./cmd

docker-build:
	docker build -t $(IMG) .

bundle-validate:
	$(OPERATOR_SDK) bundle validate ./bundle-v0.1.0
	$(OPERATOR_SDK) bundle validate ./bundle

bundle-previous-build:
	docker build -f bundle-v0.1.0.Dockerfile -t $(PREVIOUS_BUNDLE_IMG) .

bundle-build:
	docker build -f bundle.Dockerfile -t $(BUNDLE_IMG) .

catalog-validate:
	docker run --rm -v "$(CURDIR)/catalog/mayabank-platform-operator:/configs:ro" $(OPM_IMAGE) validate /configs

catalog-build:
	docker build -f catalog.Dockerfile -t $(CATALOG_IMG) .

controller-gen: $(CONTROLLER_GEN)

$(CONTROLLER_GEN): | $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(GO) install sigs.k8s.io/controller-tools/cmd/controller-gen@$(CONTROLLER_TOOLS_VERSION)

envtest: $(SETUP_ENVTEST)

$(SETUP_ENVTEST): | $(LOCALBIN)
	GOBIN=$(LOCALBIN) $(GO) install sigs.k8s.io/controller-runtime/tools/setup-envtest@$(ENVTEST_VERSION)

$(LOCALBIN):
	mkdir -p $(LOCALBIN)

clean:
	rm -rf $(LOCALBIN)
