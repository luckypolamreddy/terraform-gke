resource "google_secret_manager_secret" "secrets" {
  for_each = toset(var.secret_ids)

  secret_id = each.value
  project   = var.project_id

  replication {
    auto {}
  }

  labels = var.labels

  lifecycle {
    prevent_destroy = true
  }
}

# Grant service account access to secrets
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = {
    for binding in var.iam_bindings :
    "${binding.secret_id}-${binding.role}-${binding.member}" => binding
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.value.secret_id].secret_id
  role      = each.value.role
  member    = each.value.member
}
