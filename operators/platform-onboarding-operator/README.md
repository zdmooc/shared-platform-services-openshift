# MayaBank Platform Onboarding Operator

Status: **K3 / I2 API BOOTSTRAP — IMPLEMENTED / CI PENDING / NO RUNTIME CLAIM**

This operator materializes D-093/K2. `CapabilityConsumption` is the canonical Kubernetes Platform API.

## Current I2 scope

- Go/Kubebuilder-compatible project layout;
- `platform.mayabank.example/v1alpha1` API;
- cluster-scoped `CapabilityConsumption` CRD;
- status/conditions model;
- ownership/lifecycle fields;
- compatibility with the existing capability modes;
- RBAC and manager deployment skeleton;
- Instant Payments sample;
- no controller reconciliation yet.

## Truth boundary

I2 is an API/schema bootstrap only. It does not prove reconciliation, Server-Side Apply, ownership conflict handling, Kind runtime, CRC runtime or production behavior.

Next gate: I3 controller + unit/envtest.
