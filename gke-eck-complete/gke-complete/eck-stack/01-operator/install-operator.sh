#!/bin/bash
###############################################################################
# Install ECK Operator (YAML-based, no Helm)
#
# SCHEDULING PROBLEM:
#   Our GKE cluster has tainted node pools (es-master-pool, es-data-pool).
#   The official ECK operator.yaml has NO nodeSelector or tolerations.
#   If the scheduler tries to place it on a tainted node → Pending forever.
#
# SOLUTION:
#   1. Install the operator normally
#   2. Immediately patch the Deployment to add nodeSelector: pool-type=system
#   3. This pins the operator to the untainted system-pool
#
# Even though system-pool already has no taints (so the operator would
# naturally land there), the explicit nodeSelector:
#   - Prevents scheduling on ES pools if system-pool is temporarily full
#   - Documents the intent clearly
#   - Protects against future taint changes
###############################################################################
set -euo pipefail

ECK_VERSION="${ECK_VERSION:-2.16.0}"
BASE_URL="https://download.elastic.co/downloads/eck/${ECK_VERSION}"

echo "============================================="
echo "  Installing ECK Operator v${ECK_VERSION}"
echo "============================================="

# ── 1. Install CRDs ──
echo "[1/5] Installing CRDs..."
kubectl create -f "${BASE_URL}/crds.yaml" 2>/dev/null \
  || kubectl replace -f "${BASE_URL}/crds.yaml"

# ── 2. Install Operator ──
echo "[2/5] Installing operator in 'elastic-system'..."
kubectl apply -f "${BASE_URL}/operator.yaml"

# ── 3. Patch: pin operator to system-pool ──
#
# WHY: The operator Deployment from elastic.co has no nodeSelector.
# Without this patch, if all system-pool nodes are briefly unavailable
# (e.g. during a node upgrade), the scheduler might try tainted nodes
# and the pod goes Pending. The nodeSelector makes the intent explicit.
#
# HOW: The system-pool GKE nodes have label "pool-type=system"
# (set in cluster-1.tfvars). This patch tells k8s: only schedule
# the operator on nodes with that label.
#
echo "[3/5] Patching operator → nodeSelector: pool-type=system..."
kubectl -n elastic-system patch deployment elastic-operator \
  --type=strategic \
  -p '{
    "spec": {
      "template": {
        "spec": {
          "nodeSelector": {
            "pool-type": "system"
          }
        }
      }
    }
  }'

# ── 4. Wait for rollout (patch triggers new pod) ──
echo "[4/5] Waiting for operator rollout..."
kubectl -n elastic-system rollout status deployment/elastic-operator --timeout=300s

# ── 5. Verify ──
echo "[5/5] Verifying..."
kubectl -n elastic-system get pods -l control-plane=elastic-operator -o wide

OPERATOR_NODE=$(kubectl -n elastic-system get pods -l control-plane=elastic-operator \
  -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null || echo "unknown")
echo ""
echo "============================================="
echo "  ECK Operator v${ECK_VERSION} is READY"
echo "  Running on node: ${OPERATOR_NODE}"
echo "  Pinned to nodes with label: pool-type=system"
echo "============================================="
