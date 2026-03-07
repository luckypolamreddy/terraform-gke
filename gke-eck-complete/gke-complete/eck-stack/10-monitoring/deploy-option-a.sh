#!/bin/bash
###############################################################################
# Deploy Monitoring — Option A (Self-Monitoring)
#
# Run AFTER the main deploy.sh has completed and cluster is green.
#
# Deploys:
#   1. Stack Monitoring (ECK built-in collectors → same cluster)
#   2. Metricbeat DaemonSet (system + ES + Kibana metrics)
#   3. Filebeat DaemonSet (all logs + slow logs)
###############################################################################
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/option-a-self-monitoring"
NS="elastic-stack"

echo "╔═════════════════════════════════════════════════════════════╗"
echo "║  Monitoring — Option A (Self-Monitoring)                   ║"
echo "╚═════════════════════════════════════════════════════════════╝"

# Verify main cluster is green
H=$(kubectl -n $NS get elasticsearch elasticsearch -o jsonpath='{.status.health}' 2>/dev/null || echo "?")
if [ "$H" != "green" ]; then
  echo "ERROR: Main cluster is not green (status: $H)"
  echo "Run the main deploy.sh first and wait for green."
  exit 1
fi
echo "Main cluster: GREEN"

echo ""
echo "━━ [1/3] Stack Monitoring (ECK built-in collectors)"
kubectl apply -f "$DIR/stack-monitoring.yaml"
echo "  ECK will deploy internal Metricbeat sidecars automatically."
echo "  Metrics visible in Kibana → Stack Monitoring within ~2 minutes."

echo ""
echo "━━ [2/3] Metricbeat DaemonSet"
kubectl apply -f "$DIR/metricbeat.yaml"
echo "  Waiting for Metricbeat pods..."
sleep 10
kubectl -n $NS get pods -l beat.k8s.elastic.co/name=metricbeat

echo ""
echo "━━ [3/3] Filebeat DaemonSet"
kubectl apply -f "$DIR/filebeat.yaml"
echo "  Waiting for Filebeat pods..."
sleep 10
kubectl -n $NS get pods -l beat.k8s.elastic.co/name=filebeat

echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║  Monitoring deployed (Option A — Self-Monitoring)          ║"
echo "╠═════════════════════════════════════════════════════════════╣"
echo "║                                                             ║"
echo "║  View in Kibana:                                            ║"
echo "║    Stack Monitoring → http://<KIBANA_IP>:5601               ║"
echo "║      → Cluster health, node stats, shard allocation         ║"
echo "║      → JVM heap, circuit breakers, thread pools             ║"
echo "║                                                             ║"
echo "║    Discover → filter by log_type:                           ║"
echo "║      es-slowlog-search — Search slow logs                   ║"
echo "║      es-slowlog-index  — Indexing slow logs                 ║"
echo "║      es-audit          — Security audit logs                ║"
echo "║      es-deprecation    — Deprecation warnings               ║"
echo "║                                                             ║"
echo "║    Dashboards:                                              ║"
echo "║      [Metricbeat System] Host overview                      ║"
echo "║      [Metricbeat System] Containers overview                ║"
echo "║                                                             ║"
echo "╚═════════════════════════════════════════════════════════════╝"
