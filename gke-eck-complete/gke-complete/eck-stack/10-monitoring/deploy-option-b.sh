#!/bin/bash
###############################################################################
# Deploy Monitoring — Option B (Dedicated Monitoring Cluster)
#
# Run AFTER the main deploy.sh has completed and cluster is green.
#
# Deploys:
#   1. es-monitor (small 2-node ES cluster for monitoring data)
#   2. kibana-monitor (monitoring Kibana with separate LB)
#   3. Stack Monitoring (main cluster → ships data to es-monitor)
#   4. Metricbeat DaemonSet (metrics → es-monitor)
#   5. Filebeat DaemonSet (logs → es-monitor)
###############################################################################
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/option-b-dedicated-monitoring"
NS="elastic-stack"

echo "╔═════════════════════════════════════════════════════════════╗"
echo "║  Monitoring — Option B (Dedicated Monitoring Cluster)      ║"
echo "╚═════════════════════════════════════════════════════════════╝"

# Verify main cluster is green
H=$(kubectl -n $NS get elasticsearch elasticsearch -o jsonpath='{.status.health}' 2>/dev/null || echo "?")
if [ "$H" != "green" ]; then
  echo "ERROR: Main cluster not green ($H). Run main deploy.sh first."
  exit 1
fi
echo "Main cluster: GREEN"

# ── 1. Monitoring cluster + Kibana ──
echo ""
echo "━━ [1/5] Deploying monitoring cluster (es-monitor × 2 + kibana-monitor)"

# Auto-generate encryption keys for monitoring Kibana
if ! kubectl -n $NS get secret kibana-monitor-encryption-keys > /dev/null 2>&1; then
  echo "  Generating encryption keys for kibana-monitor..."
  kubectl create secret generic kibana-monitor-encryption-keys \
    --from-literal=xpack.security.encryptionKey="$(openssl rand -hex 32)" \
    --from-literal=xpack.encryptedSavedObjects.encryptionKey="$(openssl rand -hex 32)" \
    --from-literal=xpack.reporting.encryptionKey="$(openssl rand -hex 32)" \
    -n $NS
fi

kubectl apply -f "$DIR/monitoring-cluster.yaml"

echo "  Waiting for es-monitor to be green (2-3 min)..."
T=0
while [ $T -lt 600 ]; do
  MH=$(kubectl -n $NS get elasticsearch es-monitor -o jsonpath='{.status.health}' 2>/dev/null || echo "?")
  echo "  [${T}s] es-monitor health: $MH"
  [ "$MH" = "green" ] && break
  sleep 20; T=$((T+20))
done

echo "  Waiting for kibana-monitor..."
T=0
while [ $T -lt 300 ]; do
  KH=$(kubectl -n $NS get kibana kibana-monitor -o jsonpath='{.status.health}' 2>/dev/null || echo "?")
  [ "$KH" = "green" ] && { echo "  kibana-monitor: GREEN"; break; }
  sleep 15; T=$((T+15))
done

# ── 2. Stack Monitoring (main → es-monitor) ──
echo ""
echo "━━ [2/5] Stack Monitoring (main cluster → es-monitor)"
kubectl apply -f "$DIR/stack-monitoring.yaml"
echo "  ECK will ship monitoring data to es-monitor."

# ── 3. Metricbeat ──
echo ""
echo "━━ [3/5] Metricbeat DaemonSet (→ es-monitor)"
kubectl apply -f "$DIR/metricbeat.yaml"
sleep 10
kubectl -n $NS get pods -l beat.k8s.elastic.co/name=metricbeat

# ── 4. Filebeat ──
echo ""
echo "━━ [4/5] Filebeat DaemonSet (→ es-monitor)"
kubectl apply -f "$DIR/filebeat.yaml"
sleep 10
kubectl -n $NS get pods -l beat.k8s.elastic.co/name=filebeat

# ── 5. Summary ──
echo ""
echo "━━ [5/5] Summary"
echo ""
kubectl -n $NS get elasticsearch,kibana
echo ""
kubectl -n $NS get pods -o wide | grep -E "monitor|metricbeat|filebeat"
echo ""

MON_KB_IP=$(kubectl -n $NS get svc kibana-monitor-kb-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<pending>")
MON_ES_PASS=$(kubectl -n $NS get secret es-monitor-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d 2>/dev/null || echo "?")

echo "╔═════════════════════════════════════════════════════════════╗"
echo "║  Monitoring deployed (Option B — Dedicated Cluster)        ║"
echo "╠═════════════════════════════════════════════════════════════╣"
echo "║                                                             ║"
echo "║  Monitoring Kibana:  http://${MON_KB_IP}:5601               "
echo "║  Username: elastic                                          ║"
echo "║  Password: ${MON_ES_PASS}                                   "
echo "║                                                             ║"
echo "║  Main Kibana      → for your application data               ║"
echo "║  Monitoring Kibana → for cluster health & ops               ║"
echo "║                                                             ║"
echo "║  View:                                                      ║"
echo "║    Stack Monitoring → cluster health, nodes, shards         ║"
echo "║    Discover → slow logs (es-slowlog-search, es-slowlog-index)║"
echo "║    Dashboards → [Metricbeat System] Host overview           ║"
echo "║                                                             ║"
echo "║  If main cluster goes DOWN, monitoring still works!         ║"
echo "║                                                             ║"
echo "╚═════════════════════════════════════════════════════════════╝"
