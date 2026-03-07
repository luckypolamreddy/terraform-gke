# =============================================================================
# Project B — Backup Plan for Cluster 1
# =============================================================================

project_id       = "gcp-project-b-id"              # CHANGE
region           = "us-east1"
state_bucket     = "gcp-project-b-id-tf-state"     # CHANGE
cluster_name     = "projb-cluster-1"
backup_plan_name = "projb-cluster-1-backup-plan"

schedule_type = "rpo"
rpo_minutes   = 1440
paused        = false

delete_lock_days = 0
retain_days      = 7
retention_locked = false

scope      = "selected_namespaces"
namespaces = ["elastic-system", "elastic-stack"]

include_volumes = true
include_secrets = true

labels = {
  project      = "project-b"
  cluster-name = "projb-cluster-1"
  managed-by   = "terraform"
}
