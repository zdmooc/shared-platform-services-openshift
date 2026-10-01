# Runtime Evidence

Repository completion and CI success do not imply OpenShift runtime proof.

For each runtime validation create:

```text
evidence/YYYY-MM-DD/Sx/
  CONTEXT.md
  COMMANDS.txt
  RESULTS.md
  manifests/
```

Minimum metadata:
- date/time;
- Git commit SHA;
- cluster/context;
- OpenShift/Kubernetes version;
- namespaces;
- expected result;
- observed result;
- rollback result where applicable.

Allowed claim states:
- DESIGNED
- IMPLEMENTED
- CI_VALIDATED
- DEPLOYED
- RUNTIME_PROVEN
