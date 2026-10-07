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

.PHONY: all fmt vet test generate manifests verify build docker-build controller-gen envtest clean

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
