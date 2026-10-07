package controller

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
	ctrlmetrics "sigs.k8s.io/controller-runtime/pkg/metrics"
)

var (
	reconcileTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mayabank_platform_operator_reconcile_total",
			Help: "Total number of CapabilityConsumption reconciliations by bounded outcome.",
		},
		[]string{"outcome"},
	)
	reconcileDuration = prometheus.NewHistogram(
		prometheus.HistogramOpts{
			Name:    "mayabank_platform_operator_reconcile_duration_seconds",
			Help:    "Duration of CapabilityConsumption reconciliation.",
			Buckets: prometheus.DefBuckets,
		},
	)
	retryableFailureTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "mayabank_platform_operator_retryable_failures_total",
			Help: "Retryable CapabilityConsumption reconcile failures by bounded stage.",
		},
		[]string{"stage"},
	)
)

func init() {
	ctrlmetrics.Registry.MustRegister(reconcileTotal, reconcileDuration, retryableFailureTotal)
}

func startReconcileMetrics() func(string) {
	started := time.Now()
	return func(outcome string) {
		reconcileTotal.WithLabelValues(outcome).Inc()
		reconcileDuration.Observe(time.Since(started).Seconds())
	}
}
