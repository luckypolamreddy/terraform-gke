#!/bin/bash
# ============================================================
# Import Existing GKE Clusters into Terraform
# ============================================================
#
# This script discovers an existing GKE cluster and its node pools,
# generates the matching .tfvars file, and runs terraform import
# to bring it under Terraform management.
#
# Usage:
#   ./import-gke-cluster.sh \
#     --project pg-us-n-app-259723 \
#     --cluster my-existing-cluster \
#     --region us-east1 \
#     --state-bucket my-tf-state-bucket \
#     [--dry-run]
#
# What it does:
#   1. Discovers the existing cluster configuration via gcloud
#   2. Discovers all node pools and their settings
#   3. Generates a .tfvars file matching your cluster
#   4. Runs terraform import for the cluster + each node pool
#   5. Runs terraform plan to verify zero diff (no changes needed)
#
# Prerequisites:
#   - gcloud CLI authenticated with access to the project
#   - terraform CLI installed
#   - jq installed
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $1"; }

# -------------------------------------------------------
# Parse arguments
# -------------------------------------------------------
PROJECT_ID=""
CLUSTER_NAME=""
REGION=""
STATE_BUCKET=""
DRY_RUN=false
NETWORK_MODE="default"
CLUSTER_INDEX=1
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)       PROJECT_ID="$2";     shift 2 ;;
    --cluster)       CLUSTER_NAME="$2";   shift 2 ;;
    --region)        REGION="$2";         shift 2 ;;
    --state-bucket)  STATE_BUCKET="$2";   shift 2 ;;
    --network-mode)  NETWORK_MODE="$2";   shift 2 ;;
    --cluster-index) CLUSTER_INDEX="$2";  shift 2 ;;
    --output-dir)    OUTPUT_DIR="$2";     shift 2 ;;
    --dry-run)       DRY_RUN=true;        shift ;;
    -h|--help)
      echo "Usage: $0 --project <PROJECT> --cluster <CLUSTER> --region <REGION> --state-bucket <BUCKET> [--dry-run]"
      exit 0
      ;;
    *) log_error "Unknown option: $1"; exit 1 ;;
  esac
done

# Validate required parameters
for var in PROJECT_ID CLUSTER_NAME REGION STATE_BUCKET; do
  if [[ -z "${!var}" ]]; then
    log_error "Missing required parameter: --$(echo $var | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
    exit 1
  fi
done

# Sanitize cluster name (same logic as Terraform locals)
SANITIZED_NAME=$(echo "$CLUSTER_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$REPO_ROOT/environments/$PROJECT_ID"
fi

echo ""
echo "============================================================"
echo "  Import Existing GKE Cluster into Terraform"
echo "============================================================"
echo ""
log_info "Project:        $PROJECT_ID"
log_info "Cluster:        $CLUSTER_NAME"
log_info "Sanitized name: $SANITIZED_NAME"
log_info "Region:         $REGION"
log_info "State bucket:   $STATE_BUCKET"
log_info "Network mode:   $NETWORK_MODE"
log_info "Output dir:     $OUTPUT_DIR"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  log_warn "DRY RUN mode — will discover cluster but not run terraform import"
  echo ""
fi

# -------------------------------------------------------
# Step 1: Verify cluster exists
# -------------------------------------------------------
log_step "Step 1: Discovering existing cluster..."

CLUSTER_JSON=$(gcloud container clusters describe "$CLUSTER_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format=json 2>&1) || {
  log_error "Cluster '$CLUSTER_NAME' not found in project '$PROJECT_ID' region '$REGION'"
  log_error "Available clusters:"
  gcloud container clusters list --project="$PROJECT_ID" --format="table(name,location,status)"
  exit 1
}

log_ok "Found cluster: $CLUSTER_NAME"

# Extract cluster details
K8S_VERSION=$(echo "$CLUSTER_JSON" | jq -r '.currentMasterVersion' | cut -d'.' -f1,2)
NETWORK=$(echo "$CLUSTER_JSON" | jq -r '.network // "default"')
SUBNETWORK=$(echo "$CLUSTER_JSON" | jq -r '.subnetwork // "default"')
LOCATION=$(echo "$CLUSTER_JSON" | jq -r '.location')
HTTP_LB=$(echo "$CLUSTER_JSON" | jq -r '.addonsConfig.httpLoadBalancing.disabled // false' | sed 's/true/false/;s/false/true/' )
BACKUP_AGENT=$(echo "$CLUSTER_JSON" | jq -r '.addonsConfig.gkeBackupAgentConfig.enabled // false')
COST_ALLOC=$(echo "$CLUSTER_JSON" | jq -r '.costManagementConfig.enabled // false')
MANAGED_PROM=$(echo "$CLUSTER_JSON" | jq -r '.monitoringConfig.managedPrometheusConfig.enabled // false')
LOGGING_COMPS=$(echo "$CLUSTER_JSON" | jq -r '[.loggingConfig.componentConfig.enableComponents[]? // empty] | if length == 0 then ["SYSTEM_COMPONENTS", "WORKLOADS"] else . end | map("\"" + . + "\"") | join(", ")')
MONITOR_COMPS=$(echo "$CLUSTER_JSON" | jq -r '[.monitoringConfig.componentConfig.enableComponents[]? // empty] | if length == 0 then ["SYSTEM_COMPONENTS"] else . end | map("\"" + . + "\"") | join(", ")')
DELETION_PROT=$(echo "$CLUSTER_JSON" | jq -r '.deletionProtection // false')

# Maintenance window
MAINT_START=$(echo "$CLUSTER_JSON" | jq -r '.maintenancePolicy.window.recurringWindow.window.startTime // "2026-01-01T00:00:00Z"')
MAINT_END=$(echo "$CLUSTER_JSON" | jq -r '.maintenancePolicy.window.recurringWindow.window.endTime // "2026-01-02T00:00:00Z"')
MAINT_RECUR=$(echo "$CLUSTER_JSON" | jq -r '.maintenancePolicy.window.recurringWindow.recurrence // "FREQ=WEEKLY;BYDAY=SA"')

echo ""
log_info "Cluster Details:"
echo "  Kubernetes version: $K8S_VERSION"
echo "  Location:           $LOCATION"
echo "  Network:            $NETWORK"
echo "  Subnetwork:         $SUBNETWORK"
echo "  HTTP LB:            $HTTP_LB"
echo "  Backup agent:       $BACKUP_AGENT"
echo "  Cost allocation:    $COST_ALLOC"
echo "  Managed Prometheus: $MANAGED_PROM"
echo "  Deletion protection: $DELETION_PROT"

# -------------------------------------------------------
# Step 2: Discover node pools
# -------------------------------------------------------
log_step "Step 2: Discovering node pools..."

NODE_POOLS_JSON=$(gcloud container node-pools list \
  --cluster="$CLUSTER_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format=json)

NUM_POOLS=$(echo "$NODE_POOLS_JSON" | jq length)
log_ok "Found $NUM_POOLS node pool(s)"

# Build node_pools block
NODE_POOLS_TF=""
NODE_POOL_NAMES=()

for i in $(seq 0 $((NUM_POOLS - 1))); do
  POOL=$(echo "$NODE_POOLS_JSON" | jq ".[$i]")
  NP_NAME=$(echo "$POOL" | jq -r '.name')
  NP_MACHINE=$(echo "$POOL" | jq -r '.config.machineType')
  NP_COUNT=$(echo "$POOL" | jq -r '.initialNodeCount // 1')
  NP_DISK_TYPE=$(echo "$POOL" | jq -r '.config.diskType // "pd-standard"')
  NP_DISK_SIZE=$(echo "$POOL" | jq -r '.config.diskSizeGb // 100')
  NP_IMAGE=$(echo "$POOL" | jq -r '.config.imageType // "COS_CONTAINERD"')
  NP_AUTOSCALE=$(echo "$POOL" | jq -r 'if .autoscaling.enabled then "true" else "false" end')
  NP_MIN=$(echo "$POOL" | jq -r '.autoscaling.minNodeCount // 0')
  NP_MAX=$(echo "$POOL" | jq -r '.autoscaling.maxNodeCount // 0')
  NP_UPGRADE=$(echo "$POOL" | jq -r 'if .management.autoUpgrade then "true" else "false" end')

  NODE_POOL_NAMES+=("$NP_NAME")

  echo ""
  echo "  Node Pool: $NP_NAME"
  echo "    Machine type:  $NP_MACHINE"
  echo "    Node count:    $NP_COUNT"
  echo "    Disk:          $NP_DISK_SIZE GB $NP_DISK_TYPE"
  echo "    Autoscaling:   $NP_AUTOSCALE (min=$NP_MIN, max=$NP_MAX)"

  # Extract labels
  LABELS_JSON=$(echo "$POOL" | jq -r '.config.labels // {}')
  LABELS_TF=""
  while IFS="=" read -r key value; do
    if [[ -n "$key" && "$key" != "null" ]]; then
      LABELS_TF+="        $key = \"$value\"\n"
    fi
  done < <(echo "$LABELS_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null || true)

  if [[ -z "$LABELS_TF" ]]; then
    LABELS_TF="        node-pool = \"$NP_NAME\"\n"
  fi

  # Extract taints
  TAINTS_JSON=$(echo "$POOL" | jq -r '.config.taints // []')
  NUM_TAINTS=$(echo "$TAINTS_JSON" | jq length)
  TAINTS_TF=""

  if [[ "$NUM_TAINTS" -gt 0 ]]; then
    for t in $(seq 0 $((NUM_TAINTS - 1))); do
      T_KEY=$(echo "$TAINTS_JSON" | jq -r ".[$t].key")
      T_VAL=$(echo "$TAINTS_JSON" | jq -r ".[$t].value")
      T_EFF=$(echo "$TAINTS_JSON" | jq -r ".[$t].effect")
      TAINTS_TF+="        {\n"
      TAINTS_TF+="          key    = \"$T_KEY\"\n"
      TAINTS_TF+="          value  = \"$T_VAL\"\n"
      TAINTS_TF+="          effect = \"$T_EFF\"\n"
      TAINTS_TF+="        },\n"
      echo "    Taint:         $T_KEY=$T_VAL:$T_EFF"
    done
  fi

  # Build this node pool entry
  NODE_POOLS_TF+="  {\n"
  NODE_POOLS_TF+="    name               = \"$NP_NAME\"\n"
  NODE_POOLS_TF+="    machine_type       = \"$NP_MACHINE\"\n"
  NODE_POOLS_TF+="    node_count         = $NP_COUNT\n"
  NODE_POOLS_TF+="    disk_type          = \"$NP_DISK_TYPE\"\n"
  NODE_POOLS_TF+="    disk_size_gb       = $NP_DISK_SIZE\n"
  NODE_POOLS_TF+="    image_type         = \"$NP_IMAGE\"\n"
  NODE_POOLS_TF+="    enable_autoscaling = $NP_AUTOSCALE\n"
  NODE_POOLS_TF+="    min_node_count     = $NP_MIN\n"
  NODE_POOLS_TF+="    max_node_count     = $NP_MAX\n"
  NODE_POOLS_TF+="    auto_upgrade       = $NP_UPGRADE\n"
  NODE_POOLS_TF+="    labels = {\n"
  NODE_POOLS_TF+="$LABELS_TF"
  NODE_POOLS_TF+="    }\n"
  NODE_POOLS_TF+="    taints = [\n"
  if [[ -n "$TAINTS_TF" ]]; then
    NODE_POOLS_TF+="$TAINTS_TF"
  fi
  NODE_POOLS_TF+="    ]\n"
  NODE_POOLS_TF+="  },\n"
done

# -------------------------------------------------------
# Step 3: Generate .tfvars file
# -------------------------------------------------------
log_step "Step 3: Generating .tfvars file..."

mkdir -p "$OUTPUT_DIR"
TFVARS_FILE="$OUTPUT_DIR/cluster-imported-${SANITIZED_NAME}.tfvars"

cat > "$TFVARS_FILE" << TFVARS_EOF
# ============================================================
# IMPORTED CLUSTER: $CLUSTER_NAME
# ============================================================
# Auto-generated by import-gke-cluster.sh on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Source: gcloud container clusters describe $CLUSTER_NAME
#
# Review this file and adjust values if needed before
# running terraform plan to verify zero-diff.
# ============================================================

project_id = "$PROJECT_ID"
region     = "$REGION"
location   = "$LOCATION"

# Network
network_mode = "$NETWORK_MODE"

# Cluster
kubernetes_version = "$K8S_VERSION"

# Maintenance
maintenance = {
  start_time = "$MAINT_START"
  end_time   = "$MAINT_END"
  recurrence = "$MAINT_RECUR"
}

# Features
enable_http_load_balancing = $HTTP_LB
enable_backup              = $BACKUP_AGENT
enable_cost_allocation     = $COST_ALLOC
enable_managed_prometheus  = $MANAGED_PROM

# Logging
logging_components    = [$LOGGING_COMPS]
monitoring_components = [$MONITOR_COMPS]

# Usage metering
usage_metering_dataset_id      = ""
enable_network_egress_metering = false

deletion_protection = $DELETION_PROT

# ============================================================
# Node Pools (discovered from existing cluster)
# ============================================================
node_pools = [
$(echo -e "$NODE_POOLS_TF")
]
TFVARS_EOF

log_ok "Generated: $TFVARS_FILE"

# -------------------------------------------------------
# Step 4: Terraform init
# -------------------------------------------------------
log_step "Step 4: Initializing Terraform..."

CLUSTER_STACK="$REPO_ROOT/stacks/cluster"
BACKEND_PREFIX="cluster/$PROJECT_ID/$SANITIZED_NAME"

if [[ "$DRY_RUN" == "true" ]]; then
  log_warn "DRY RUN: Would run terraform init in $CLUSTER_STACK"
  log_warn "DRY RUN: Backend: gs://$STATE_BUCKET/$BACKEND_PREFIX"
else
  cd "$CLUSTER_STACK"
  terraform init \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="prefix=$BACKEND_PREFIX" \
    -input=false \
    -reconfigure
  log_ok "Terraform initialized"
fi

# -------------------------------------------------------
# Step 5: Import cluster
# -------------------------------------------------------
log_step "Step 5: Importing GKE cluster..."

CLUSTER_IMPORT_ID="projects/$PROJECT_ID/locations/$LOCATION/clusters/$CLUSTER_NAME"

echo ""
echo "  Resource: module.gke_cluster.google_container_cluster.cluster"
echo "  ID:       $CLUSTER_IMPORT_ID"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  log_warn "DRY RUN: Would run terraform import"
  echo "  terraform import \\"
  echo "    -var-file=\"$TFVARS_FILE\" \\"
  echo "    -var=\"cluster_name=$SANITIZED_NAME\" \\"
  if [[ "$NETWORK_MODE" == "custom" ]]; then
    echo "    -var=\"cluster_index=$CLUSTER_INDEX\" \\"
  fi
  echo "    'module.gke_cluster.google_container_cluster.cluster' \\"
  echo "    '$CLUSTER_IMPORT_ID'"
else
  IMPORT_VARS="-var-file=$TFVARS_FILE -var=cluster_name=$SANITIZED_NAME"
  if [[ "$NETWORK_MODE" == "custom" ]]; then
    IMPORT_VARS="$IMPORT_VARS -var=cluster_index=$CLUSTER_INDEX"
  fi

  terraform import $IMPORT_VARS \
    'module.gke_cluster.google_container_cluster.cluster' \
    "$CLUSTER_IMPORT_ID" || {
      log_error "Failed to import cluster. It may already be in state."
      log_warn "If already imported, this is safe to ignore. Continuing..."
    }
  log_ok "Cluster imported"
fi

# -------------------------------------------------------
# Step 6: Import node pools
# -------------------------------------------------------
log_step "Step 6: Importing node pools..."

for NP_NAME in "${NODE_POOL_NAMES[@]}"; do
  NP_IMPORT_ID="projects/$PROJECT_ID/locations/$LOCATION/clusters/$CLUSTER_NAME/nodePools/$NP_NAME"

  echo ""
  echo "  Resource: module.gke_cluster.google_container_node_pool.pools[\"$NP_NAME\"]"
  echo "  ID:       $NP_IMPORT_ID"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "DRY RUN: Would import node pool '$NP_NAME'"
  else
    terraform import $IMPORT_VARS \
      "module.gke_cluster.google_container_node_pool.pools[\"$NP_NAME\"]" \
      "$NP_IMPORT_ID" || {
        log_error "Failed to import node pool '$NP_NAME'. May already be in state."
        log_warn "Continuing..."
      }
    log_ok "Node pool '$NP_NAME' imported"
  fi
done

# -------------------------------------------------------
# Step 7: Import subnet (custom mode only)
# -------------------------------------------------------
if [[ "$NETWORK_MODE" == "custom" && "$SUBNETWORK" != "default" ]]; then
  log_step "Step 7: Importing subnet..."

  SUBNET_NAME=$(basename "$SUBNETWORK")
  SUBNET_IMPORT_ID="projects/$PROJECT_ID/regions/$REGION/subnetworks/$SUBNET_NAME"

  echo ""
  echo "  Resource: module.subnet[0].google_compute_subnetwork.subnet"
  echo "  ID:       $SUBNET_IMPORT_ID"

  if [[ "$DRY_RUN" == "true" ]]; then
    log_warn "DRY RUN: Would import subnet '$SUBNET_NAME'"
  else
    terraform import $IMPORT_VARS \
      'module.subnet[0].google_compute_subnetwork.subnet' \
      "$SUBNET_IMPORT_ID" || {
        log_error "Failed to import subnet."
        log_warn "Continuing..."
      }
    log_ok "Subnet imported"
  fi
else
  log_step "Step 7: Skipping subnet import (default network mode)"
fi

# -------------------------------------------------------
# Step 8: Verify with terraform plan
# -------------------------------------------------------
log_step "Step 8: Running terraform plan to verify zero-diff..."

echo ""
if [[ "$DRY_RUN" == "true" ]]; then
  log_warn "DRY RUN: Would run terraform plan"
  echo ""
  echo "  terraform plan \\"
  echo "    -var-file=\"$TFVARS_FILE\" \\"
  echo "    -var=\"cluster_name=$SANITIZED_NAME\" \\"
  echo "    -detailed-exitcode"
else
  set +e
  terraform plan $IMPORT_VARS -detailed-exitcode 2>&1 | tee /tmp/tf-import-plan.txt
  PLAN_EXIT=$?
  set -e

  echo ""
  if [[ $PLAN_EXIT -eq 0 ]]; then
    log_ok "PERFECT: No changes detected. Cluster fully imported!"
  elif [[ $PLAN_EXIT -eq 2 ]]; then
    log_warn "Terraform detected differences between imported state and your .tfvars."
    log_warn "This is normal — review the plan output above and adjust:"
    echo ""
    echo "  1. Edit: $TFVARS_FILE"
    echo "  2. Re-run: terraform plan -var-file=$TFVARS_FILE -var=cluster_name=$SANITIZED_NAME"
    echo "  3. Repeat until you see 'No changes'"
    echo ""
    log_warn "Common differences to fix:"
    echo "  - maintenance window times"
    echo "  - node pool disk types or sizes"
    echo "  - labels or taints formatting"
    echo "  - kubernetes version (patch vs minor)"
  else
    log_error "Terraform plan failed. Check the output above."
    exit 1
  fi
fi

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo ""
echo "============================================================"
echo "  Import Summary"
echo "============================================================"
echo ""
log_ok "Cluster:      $CLUSTER_NAME -> $SANITIZED_NAME"
log_ok "Node pools:   ${NODE_POOL_NAMES[*]}"
log_ok "tfvars file:  $TFVARS_FILE"
log_ok "State bucket: gs://$STATE_BUCKET/$BACKEND_PREFIX"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Next steps (dry run was used):"
  echo ""
  echo "  1. Review the generated tfvars: $TFVARS_FILE"
  echo "  2. Run again without --dry-run to perform the actual import"
else
  echo "Next steps:"
  echo ""
  echo "  1. Review the plan output for any diffs"
  echo "  2. Adjust $TFVARS_FILE if needed"
  echo "  3. Run: cd $CLUSTER_STACK && terraform plan -var-file=$TFVARS_FILE -var=cluster_name=$SANITIZED_NAME"
  echo "  4. Once plan shows 'No changes', the cluster is fully managed by Terraform"
  echo "  5. Future changes go through the 02-cluster.yml pipeline"
fi
echo ""
