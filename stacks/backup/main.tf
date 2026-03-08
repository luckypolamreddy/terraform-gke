locals {
  cluster_id       = "projects/${var.project_id}/locations/${var.location}/clusters/${var.cluster_name}"
  backup_plan_name = "${var.cluster_name}-backup-01"
}

module "gke_backup_plan" {
  source = "../../modules/gke-backup-plan"

  project_id       = var.project_id
  backup_plan_name = local.backup_plan_name
  location         = var.location
  cluster_id       = local.cluster_id

  backup_namespaces  = var.backup_namespaces
  rpo_minutes        = var.rpo_minutes
  backup_retain_days = var.backup_retain_days
  include_volume_data = var.include_volume_data
  include_secrets     = var.include_secrets
  paused             = var.paused
}
