output "secret_ids" {
  description = "Map of secret name to full ID"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.id }
}

output "secret_names" {
  description = "List of created secret IDs"
  value       = [for v in google_secret_manager_secret.secrets : v.secret_id]
}
