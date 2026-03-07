###############################################################################
# GKE Backup Plan Module - Generic
# Supports: cron or RPO schedule, all / selected_namespaces / selected_applications
# NOTE: Cannot be destroyed while backups exist. Pause first, let backups
#       expire per retention policy, then destroy.
###############################################################################

resource "google_gke_backup_backup_plan" "this" {
  name     = var.name
  project  = var.project_id
  location = var.location
  cluster  = var.cluster_id

  # --- Retention ---
  retention_policy {
    backup_delete_lock_days = var.delete_lock_days
    backup_retain_days      = var.retain_days
    locked                  = var.retention_locked
  }

  # --- Schedule ---
  backup_schedule {
    paused = var.paused

    # RPO-based (mutually exclusive with cron)
    dynamic "rpo_config" {
      for_each = var.schedule_type == "rpo" ? [1] : []
      content {
        target_rpo_minutes = var.rpo_minutes
      }
    }

    # Cron-based
    cron_schedule = var.schedule_type == "cron" ? var.cron_schedule : null
  }

  # --- Scope ---
  backup_config {
    include_volume_data = var.include_volumes
    include_secrets     = var.include_secrets

    # Option 1: all namespaces
    all_namespaces = var.scope == "all" ? true : null

    # Option 2: selected namespaces
    dynamic "selected_namespaces" {
      for_each = var.scope == "selected_namespaces" ? [1] : []
      content {
        namespaces = var.namespaces
      }
    }

    # Option 3: selected applications
    dynamic "selected_applications" {
      for_each = var.scope == "selected_applications" ? [1] : []
      content {
        dynamic "namespaced_names" {
          for_each = var.applications
          content {
            namespace = namespaced_names.value.namespace
            name      = namespaced_names.value.name
          }
        }
      }
    }
  }

  labels = var.labels
}
