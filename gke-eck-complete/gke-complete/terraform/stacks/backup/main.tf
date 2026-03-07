###############################################################################
# Backup Stack — INDEPENDENT lifecycle
# Created AFTER cluster. PAUSED before cluster destroy. Destroyed only after
# all backups have expired per retention policy.
###############################################################################

data "terraform_remote_state" "cluster" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "clusters/${var.cluster_name}"
  }
}

module "backup_plan" {
  source = "../../modules/gke-backup-plan"

  project_id  = var.project_id
  location    = data.terraform_remote_state.cluster.outputs.cluster_location
  name        = var.backup_plan_name
  cluster_id  = data.terraform_remote_state.cluster.outputs.cluster_id

  # Schedule
  schedule_type = var.schedule_type
  rpo_minutes   = var.rpo_minutes
  cron_schedule = var.cron_schedule
  paused        = var.paused

  # Retention
  delete_lock_days = var.delete_lock_days
  retain_days      = var.retain_days
  retention_locked = var.retention_locked

  # Scope
  scope            = var.scope
  namespaces       = var.namespaces
  applications     = var.applications
  include_volumes  = var.include_volumes
  include_secrets  = var.include_secrets

  labels = var.labels
}
