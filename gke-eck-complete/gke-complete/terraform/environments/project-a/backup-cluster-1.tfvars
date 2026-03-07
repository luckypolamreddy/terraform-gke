# =============================================================================
# Project A — Backup Plan for Cluster 1
# =============================================================================

project_id       = "gcp-project-a-id"              # CHANGE
region           = "us-east1"
state_bucket     = "gcp-project-a-id-tf-state"     # CHANGE
cluster_name     = "proja-cluster-1"
backup_plan_name = "proja-cluster-1-backup-plan"

# --- Schedule: RPO daily ---
schedule_type = "rpo"
rpo_minutes   = 1440
paused        = false

# --- Retention ---
delete_lock_days = 0
retain_days      = 7
retention_locked = false

# --- Scope: Elastic namespaces ---
scope = "selected_namespaces"
namespaces = [
  "elastic-system",
  "elastic-stack",
]

include_volumes = true
include_secrets = true

labels = {
  project      = "project-a"
  cluster-name = "proja-cluster-1"
  managed-by   = "terraform"
}
