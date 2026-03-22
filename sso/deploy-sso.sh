#!/bin/bash
# Deploy SSO for GKE and ECK Clusters
#
# Usage:
#   ./deploy-sso.sh --project <PROJECT_ID> \
#                    --cluster <CLUSTER_NAME> \
#                    --region <REGION> \
#                    --tenant-id <AZURE_TENANT_ID> \
#                    --client-id <AZURE_CLIENT_ID> \
#                    --client-secret <AZURE_CLIENT_SECRET> \
#                    --kibana-host <KIBANA_HOSTNAME> \
#                    [--admin-group-id <AZURE_AD_GROUP_ID>] \
#                    [--editor-group-id <AZURE_AD_GROUP_ID>] \
#                    [--viewer-group-id <AZURE_AD_GROUP_ID>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# -------------------------------------------------------
# Parse arguments
# -------------------------------------------------------
PROJECT_ID=""
CLUSTER_NAME=""
REGION=""
AZURE_TENANT_ID=""
OIDC_CLIENT_ID=""
OIDC_CLIENT_SECRET=""
KIBANA_HOST=""
ADMIN_GROUP_ID="REPLACE_WITH_ADMIN_GROUP_ID"
EDITOR_GROUP_ID="REPLACE_WITH_EDITOR_GROUP_ID"
VIEWER_GROUP_ID="REPLACE_WITH_VIEWER_GROUP_ID"
SKIP_TERRAFORM=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)        PROJECT_ID="$2";          shift 2 ;;
    --cluster)        CLUSTER_NAME="$2";        shift 2 ;;
    --region)         REGION="$2";              shift 2 ;;
    --tenant-id)      AZURE_TENANT_ID="$2";     shift 2 ;;
    --client-id)      OIDC_CLIENT_ID="$2";      shift 2 ;;
    --client-secret)  OIDC_CLIENT_SECRET="$2";  shift 2 ;;
    --kibana-host)    KIBANA_HOST="$2";         shift 2 ;;
    --admin-group-id) ADMIN_GROUP_ID="$2";      shift 2 ;;
    --editor-group-id) EDITOR_GROUP_ID="$2";    shift 2 ;;
    --viewer-group-id) VIEWER_GROUP_ID="$2";    shift 2 ;;
    --skip-terraform) SKIP_TERRAFORM=true;      shift ;;
    --dry-run)        DRY_RUN=true;             shift ;;
    *) log_error "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate required parameters
for var in PROJECT_ID CLUSTER_NAME REGION AZURE_TENANT_ID OIDC_CLIENT_ID OIDC_CLIENT_SECRET KIBANA_HOST; do
  if [[ -z "${!var}" ]]; then
    log_error "Missing required parameter: --$(echo $var | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
    exit 1
  fi
done

echo ""
echo "============================================"
echo "  ECK Single Sign-On Deployment"
echo "============================================"
echo ""
log_info "Project:     $PROJECT_ID"
log_info "Cluster:     $CLUSTER_NAME"
log_info "Region:      $REGION"
log_info "Tenant ID:   $AZURE_TENANT_ID"
log_info "Client ID:   $OIDC_CLIENT_ID"
log_info "Kibana Host: $KIBANA_HOST"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  log_warn "DRY RUN mode - no changes will be applied"
  echo ""
fi

# -------------------------------------------------------
# Step 1: Get GKE credentials
# -------------------------------------------------------
log_info "Step 1: Connecting to GKE cluster..."
if [[ "$DRY_RUN" != "true" ]]; then
  gcloud container clusters get-credentials "$CLUSTER_NAME" \
    --region "$REGION" \
    --project "$PROJECT_ID"
  log_ok "Connected to GKE cluster"
else
  log_warn "Would connect to GKE cluster $CLUSTER_NAME"
fi

# -------------------------------------------------------
# Step 2: Apply GKE IAM bindings via Terraform
# -------------------------------------------------------
if [[ "$SKIP_TERRAFORM" != "true" ]]; then
  log_info "Step 2: Applying GKE IAM bindings..."
  if [[ "$DRY_RUN" != "true" ]]; then
    cd "$SCRIPT_DIR/02-gke-rbac"
    terraform init -input=false
    terraform apply -auto-approve \
      -var="project_id=$PROJECT_ID" \
      -var="cluster_name=$CLUSTER_NAME" \
      -var="cluster_location=$REGION"
    cd "$SCRIPT_DIR"
    log_ok "GKE IAM bindings applied"
  else
    log_warn "Would apply Terraform GKE IAM bindings"
  fi
else
  log_warn "Skipping Terraform (--skip-terraform)"
fi

# -------------------------------------------------------
# Step 3: Create OIDC client secret in Kubernetes
# -------------------------------------------------------
log_info "Step 3: Creating OIDC client secret..."
if [[ "$DRY_RUN" != "true" ]]; then
  kubectl create secret generic oidc-client-secret \
    --namespace=elastic-stack \
    --from-literal=client-id="$OIDC_CLIENT_ID" \
    --from-literal=client-secret="$OIDC_CLIENT_SECRET" \
    --dry-run=client -o yaml | kubectl apply -f -
  log_ok "OIDC client secret created/updated"
else
  log_warn "Would create OIDC client secret in elastic-stack namespace"
fi

# -------------------------------------------------------
# Step 4: Apply Elasticsearch OIDC configuration
# -------------------------------------------------------
log_info "Step 4: Applying Elasticsearch OIDC configuration..."

# Generate the Elasticsearch config with actual values
TEMP_ES_CONFIG=$(mktemp)
sed -e "s|\${OIDC_CLIENT_ID}|${OIDC_CLIENT_ID}|g" \
    -e "s|\${AZURE_TENANT_ID}|${AZURE_TENANT_ID}|g" \
    -e "s|\${KIBANA_HOST}|${KIBANA_HOST}|g" \
    "$SCRIPT_DIR/03-elasticsearch-oidc/elasticsearch-oidc-config.yaml" > "$TEMP_ES_CONFIG"

if [[ "$DRY_RUN" != "true" ]]; then
  kubectl apply -f "$TEMP_ES_CONFIG"
  rm -f "$TEMP_ES_CONFIG"
  log_ok "Elasticsearch OIDC configuration applied"

  log_info "Waiting for Elasticsearch to be ready (this may take several minutes)..."
  kubectl wait --for=condition=Ready \
    elasticsearch/elasticsearch \
    --namespace=elastic-stack \
    --timeout=600s
  log_ok "Elasticsearch is ready"
else
  log_warn "Would apply Elasticsearch OIDC config"
  rm -f "$TEMP_ES_CONFIG"
fi

# -------------------------------------------------------
# Step 5: Apply Kibana OIDC configuration
# -------------------------------------------------------
log_info "Step 5: Applying Kibana OIDC configuration..."

TEMP_KB_CONFIG=$(mktemp)
sed -e "s|\${KIBANA_HOST}|${KIBANA_HOST}|g" \
    "$SCRIPT_DIR/04-kibana-oidc/kibana-oidc-config.yaml" > "$TEMP_KB_CONFIG"

if [[ "$DRY_RUN" != "true" ]]; then
  kubectl apply -f "$TEMP_KB_CONFIG"
  rm -f "$TEMP_KB_CONFIG"
  log_ok "Kibana OIDC configuration applied"

  log_info "Waiting for Kibana to be ready..."
  kubectl wait --for=condition=Ready \
    kibana/kibana \
    --namespace=elastic-stack \
    --timeout=300s
  log_ok "Kibana is ready"
else
  log_warn "Would apply Kibana OIDC config"
  rm -f "$TEMP_KB_CONFIG"
fi

# -------------------------------------------------------
# Step 6: Apply Kubernetes RBAC
# -------------------------------------------------------
log_info "Step 6: Applying Kubernetes RBAC..."
if [[ "$DRY_RUN" != "true" ]]; then
  kubectl apply -f "$SCRIPT_DIR/05-k8s-rbac/namespace-rbac.yaml"
  log_ok "Kubernetes RBAC applied"
else
  log_warn "Would apply Kubernetes RBAC"
fi

# -------------------------------------------------------
# Step 7: Apply network policies
# -------------------------------------------------------
log_info "Step 7: Applying network policies for OIDC..."
if [[ "$DRY_RUN" != "true" ]]; then
  kubectl apply -f "$SCRIPT_DIR/06-network-policies/oidc-network-policy.yaml"
  log_ok "Network policies applied"
else
  log_warn "Would apply OIDC network policies"
fi

# -------------------------------------------------------
# Step 8: Create Elasticsearch role mappings
# -------------------------------------------------------
log_info "Step 8: Creating Elasticsearch SSO role mappings..."

TEMP_RM_CONFIG=$(mktemp)
sed -e "s|AZURE_AD_GROUP_ID_FOR_ECK_ADMINS|${ADMIN_GROUP_ID}|g" \
    -e "s|AZURE_AD_GROUP_ID_FOR_ECK_EDITORS|${EDITOR_GROUP_ID}|g" \
    -e "s|AZURE_AD_GROUP_ID_FOR_ECK_VIEWERS|${VIEWER_GROUP_ID}|g" \
    "$SCRIPT_DIR/03-elasticsearch-oidc/role-mappings.yaml" > "$TEMP_RM_CONFIG"

if [[ "$DRY_RUN" != "true" ]]; then
  kubectl apply -f "$TEMP_RM_CONFIG"
  rm -f "$TEMP_RM_CONFIG"

  log_info "Waiting for role mapping job to complete..."
  kubectl wait --for=condition=complete \
    job/es-sso-role-mappings \
    --namespace=elastic-stack \
    --timeout=120s
  log_ok "Elasticsearch role mappings created"
else
  log_warn "Would create Elasticsearch role mappings"
  rm -f "$TEMP_RM_CONFIG"
fi

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo "============================================"
echo "  SSO Deployment Complete!"
echo "============================================"
echo ""
log_ok "GKE cluster access: Users authenticate via @gcp.pwc.com Google accounts"
log_ok "Kibana SSO: Users authenticate via @pwc.com Office 365 accounts"
echo ""
log_info "Kibana URL: https://$KIBANA_HOST"
log_info "Login: Click 'Sign in with PwC Office 365'"
echo ""
log_info "Role Summary:"
echo "  Admins  (4): teamlead1, teamlead2, devops1, devops2"
echo "  Editors (10): developer1-10"
echo "  Viewers (6): qa1-3, analyst1-2, manager1"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  log_warn "This was a DRY RUN - no changes were applied"
fi
