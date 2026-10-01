#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-shared-observability}"
POD_NAME="${POD_NAME:-telemetry-consumer-smoke}"

kubectl -n "${NAMESPACE}" delete pod "${POD_NAME}" --ignore-not-found --wait=true >/dev/null 2>&1 || true

cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: telemetry-consumer-smoke
  namespace: shared-observability
  labels:
    app.kubernetes.io/name: telemetry-consumer-smoke
    app.kubernetes.io/part-of: shared-platform-services
spec:
  restartPolicy: Never
  containers:
    - name: curl
      image: curlimages/curl:8.10.1
      command:
        - sh
        - -ec
      args:
        - |
          now="$(date +%s)000000000"
          payload="$(printf '{"resourceMetrics":[{"scopeMetrics":[{"scope":{"name":"shared-platform-smoke"},"metrics":[{"name":"factory_consumer_smoke","gauge":{"dataPoints":[{"timeUnixNano":"%s","asInt":"1"}]}}]}]}]}' "$now")"

          code="$(curl -sS \
            -o /tmp/otlp-response \
            -w "%{http_code}" \
            -H "Content-Type: application/json" \
            -X POST \
            --data "$payload" \
            http://otel-collector.shared-observability.svc:4318/v1/metrics)"

          echo "OTLP_HTTP_STATUS=$code"
          cat /tmp/otlp-response || true
          test "$code" = "200"

          found=0
          for i in $(seq 1 30); do
            curl -fsS http://otel-collector.shared-observability.svc:8889/metrics >/tmp/metrics
            if grep -q "factory_consumer_smoke" /tmp/metrics; then
              found=1
              break
            fi
            sleep 1
          done

          test "$found" -eq 1
          grep "factory_consumer_smoke" /tmp/metrics
YAML

set +e
kubectl -n "${NAMESPACE}" wait \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/"${POD_NAME}" \
  --timeout=120s
wait_status=$?
set -e

echo "== Telemetry consumer logs"
kubectl -n "${NAMESPACE}" logs "${POD_NAME}" || true

if [[ "${wait_status}" -ne 0 ]]; then
  echo "== Telemetry consumer describe"
  kubectl -n "${NAMESPACE}" describe pod "${POD_NAME}" || true
  exit "${wait_status}"
fi

kubectl -n "${NAMESPACE}" delete pod "${POD_NAME}" --wait=true >/dev/null

echo "OTEL_CONSUMER_PATH=PASS"
