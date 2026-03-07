output "secret_ids" {
  description = "IDs of the created secrets"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.secret_id }
}

output "secret_names" {
  description = "Full resource names of the created secrets"
  value       = { for k, v in google_secret_manager_secret.secrets : k => v.name }
}
