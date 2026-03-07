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

# Cleanup backups before destroying the backup plan
resource "null_resource" "cleanup_before_destroy" {
  depends_on = [google_gke_backup_backup_plan.plan]

  triggers = {
    backup_plan_name = google_gke_backup_backup_plan.plan.name
    project_id       = var.project_id
    location         = var.location
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Pausing backup plan..."
      gcloud beta container backup-restore backup-plans update ${self.triggers.backup_plan_name} \
        --project=${self.triggers.project_id} \
        --location=${self.triggers.location} \
        --no-paused 2>/dev/null || true

      gcloud beta container backup-restore backup-plans update ${self.triggers.backup_plan_name} \
        --project=${self.triggers.project_id} \
        --location=${self.triggers.location} \
        --paused 2>/dev/null || true

      echo "Deleting existing backups..."
      BACKUPS=$(gcloud beta container backup-restore backups list \
        --backup-plan=${self.triggers.backup_plan_name} \
        --location=${self.triggers.location} \
        --project=${self.triggers.project_id} \
        --format="value(name)" 2>/dev/null || true)

      for backup in $BACKUPS; do
        echo "Deleting backup: $backup"
        gcloud beta container backup-restore backups delete "$backup" \
          --project=${self.triggers.project_id} \
          --location=${self.triggers.location} \
          --quiet 2>/dev/null || true
      done
      echo "Backup cleanup complete."
    EOT
  }
}
