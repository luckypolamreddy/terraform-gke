resource "google_gke_backup_backup_plan" "plan" {
  name     = var.backup_plan_name
  project  = var.project_id
  location = var.location
  cluster  = var.cluster_id

  retention_policy {
    backup_delete_lock_days = 0
    backup_retain_days      = var.backup_retain_days
  }

  backup_schedule {
    rpo_config {
      target_rpo_minutes = var.rpo_minutes
    }
    paused = var.paused
  }

  backup_config {
    selected_namespaces {
      namespaces = var.backup_namespaces
    }
    include_volume_data = var.include_volume_data
    include_secrets     = var.include_secrets
  }
}
