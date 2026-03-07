output "backup_plan_name" {
  description = "Name of the backup plan"
  value       = google_gke_backup_backup_plan.plan.name
}

output "backup_plan_id" {
  description = "ID of the backup plan"
  value       = google_gke_backup_backup_plan.plan.id
}
