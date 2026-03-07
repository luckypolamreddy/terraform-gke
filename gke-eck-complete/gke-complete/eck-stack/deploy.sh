#!/bin/bash
###############################################################################
# ECK Stack — Deploy Script
#
# Deploys in order with proper waits:
#   1. Namespace → 2. ECK Operator → 3. License → 4. GCS Secret
#   5. Kibana Encryption Keys (auto-generated) → 6. ConfigMaps
#   7. Security → 8. Elasticsearch (wait green)
#   9. Kibana (wait green) → 10. Snapshots → 11. Index defaults
#   12. Kibana creds → GCP Secret Manager
#
# Usage:
#   ./deploy.sh                    # Full deploy
#   ./deploy.sh --skip-operator    # Operator already installed
#   ./deploy.sh --dry-run          # Preview only
###############################################################################
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="elastic-stack"
SKIP_OP=false; DRY=false

for arg in "$@"; do
  case $arg in
    --skip-operator) SKIP_OP=true ;;
    --dry-run) DRY=true ;;
  esac
done

run() { if $DRY; then echo "  [DRY] kubectl apply -f $1"; else kubectl apply -f "$1"; fi; }

echo "╔═════════════════════════════════════════════════════════════╗"
echo "║  ECK Stack — Elastic 9.1.3 on GKE                         ║"
echo "╚═════════════════════════════════════════════════════════════╝"

# Pre-flight
kubectl cluster-info > /dev/null 2>&1 || { echo "ERROR: kubectl not connected"; exit 1; }
echo "Cluster: $(kubectl config current-context)"
echo "Nodes:   $(kubectl get nodes --no-headers | wc -l)"
echo ""

# ── 1. Namespace ──
echo "━━ [1/12] Namespace"
run "$DIR/00-namespace.yaml"

# ── 2. ECK Operator ──
echo "━━ [2/12] ECK Operator"
if $SKIP_OP; then echo "  Skipped (--skip-operator)";
else $DRY || bash "$DIR/01-operator/install-operator.sh"; fi

# ── 3. Enterprise Trial License ──
echo "━━ [3/12] Enterprise Trial License"
run "$DIR/01-operator/enterprise-trial-license.yaml"

# ── 4. GCS Credentials Secret ──
echo "━━ [4/12] GCS Credentials Secret"
if ! $DRY && ! kubectl -n $NS get secret gcs-credentials > /dev/null 2>&1; then
  echo ""
  echo "  ⚠  GCS credentials secret not found!"
  echo "     Create it:"
  echo "     kubectl create secret generic gcs-credentials \\"
  echo "       --from-file=gcs.client.default.credentials_file=/path/to/sa-key.json \\"
  echo "       -n elastic-stack"
  echo ""
  read -p "  Created? (y/N): " -r
  [[ $REPLY =~ ^[Yy]$ ]] || { echo "  Exiting."; exit 1; }
else echo "  GCS credentials: OK"; fi

# ── 5. Kibana Encryption Keys (auto-generated) ──
echo "━━ [5/12] Kibana Encryption Keys"
if ! $DRY; then
  if kubectl -n $NS get secret kibana-encryption-keys > /dev/null 2>&1; then
    echo "  Encryption keys secret already exists. Keeping existing."
  else
    echo "  Auto-generating 3 encryption keys..."
    # Generate 3 random 32-byte hex strings
    KEY1=$(openssl rand -hex 32)
    KEY2=$(openssl rand -hex 32)
    KEY3=$(openssl rand -hex 32)

    # ECK's secureSettings injects these into Kibana's keystore.
    # The key names in the secret must match the Kibana config key names exactly.
    kubectl create secret generic kibana-encryption-keys \
      --from-literal=xpack.security.encryptionKey="${KEY1}" \
      --from-literal=xpack.encryptedSavedObjects.encryptionKey="${KEY2}" \
      --from-literal=xpack.reporting.encryptionKey="${KEY3}" \
      -n $NS

    echo "  Created secret 'kibana-encryption-keys' with 3 auto-generated keys."
    echo "  These encrypt Kibana sessions, saved objects, and reports."
    echo "  They are NOT SSL certificates."
  fi
else
  echo "  [DRY] Would auto-generate 3 encryption keys"
fi

# ── 6. ConfigMaps (synonyms) ──
echo "━━ [6/12] ConfigMaps (synonyms)"
run "$DIR/03-configmaps/synonyms.yaml"

# ── 7. Security (RBAC, Network Policies, PDBs) ──
echo "━━ [7/12] Security"
run "$DIR/06-security/rbac.yaml"
run "$DIR/06-security/network-policies.yaml"
run "$DIR/06-security/pod-disruption-budgets.yaml"

# ── 8. Elasticsearch ──
echo "━━ [8/12] Elasticsearch 9.1.3 (master×3 + data×3)"
run "$DIR/04-elasticsearch/elasticsearch.yaml"
if ! $DRY; then
  echo "  Waiting for green (may take 5-15 min)..."
  T=0
  while [ $T -lt 900 ]; do
    H=$(kubectl -n $NS get elasticsearch elasticsearch -o jsonpath='{.status.health}' 2>/dev/null || echo "?")
    P=$(kubectl -n $NS get elasticsearch elasticsearch -o jsonpath='{.status.phase}' 2>/dev/null || echo "?")
    echo "  [${T}s] Health: $H | Phase: $P"
    [ "$H" = "green" ] && break
    sleep 30; T=$((T+30))
  done
fi

# ── 9. Kibana ──
echo "━━ [9/12] Kibana 9.1.3 (×2 HA)"
run "$DIR/05-kibana/kibana.yaml"
if ! $DRY; then
  echo "  Waiting for Kibana green..."
  T=0
  while [ $T -lt 600 ]; do
    H=$(kubectl -n $NS get kibana kibana -o jsonpath='{.status.health}' 2>/dev/null || echo "?")
    [ "$H" = "green" ] && { echo "  Kibana GREEN"; break; }
    sleep 15; T=$((T+15))
  done
fi

# ── 10. Snapshots ──
echo "━━ [10/12] Snapshot Repository + SLM Policy"
run "$DIR/07-snapshot/setup-snapshots.yaml"
$DRY || kubectl -n $NS wait --for=condition=complete job/setup-snapshots --timeout=300s 2>/dev/null || true

# ── 11. Index Defaults ──
echo "━━ [11/12] Index Defaults (slow logs + synonym analyzers)"
run "$DIR/09-index-settings/setup-index-defaults.yaml"
$DRY || kubectl -n $NS wait --for=condition=complete job/setup-index-defaults --timeout=300s 2>/dev/null || true

# ── 12. Kibana Creds → GCP Secret Manager ──
echo "━━ [12/12] Kibana Credentials → GCP Secret Manager"
run "$DIR/08-creds-sync/sync-to-secret-manager.yaml"
$DRY || kubectl -n $NS wait --for=condition=complete job/sync-kibana-creds --timeout=300s 2>/dev/null || true

# ── Summary ──
echo ""
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║                   DEPLOYMENT COMPLETE                      ║"
echo "╚═════════════════════════════════════════════════════════════╝"

if ! $DRY; then
  echo ""
  kubectl -n $NS get elasticsearch,kibana
  echo ""
  kubectl -n $NS get pods -o wide
  echo ""
  kubectl -n $NS get svc

  ES_PASS=$(kubectl -n $NS get secret elasticsearch-es-elastic-user -o jsonpath='{.data.elastic}' | base64 -d)
  ES_IP=$(kubectl -n $NS get svc elasticsearch-es-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<pending>")
  KB_IP=$(kubectl -n $NS get svc kibana-kb-http -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<pending>")

  echo ""
  echo "Endpoints (HTTP — no TLS, add TLS at ingress later):"
  echo "  Elasticsearch: http://${ES_IP}:9200"
  echo "  Kibana:        http://${KB_IP}:5601"
  echo "  Username:      elastic"
  echo "  Password:      ${ES_PASS}"
  echo ""
  echo "No-cluster-access login:"
  echo "  gcloud secrets versions access latest --secret=elastic-stack-kibana-credentials"
fi
