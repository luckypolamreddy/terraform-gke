###############################################################################
# Secret Manager Module - Generic
# Creates secrets with configurable replication and IAM bindings.
# Values are added separately (manually or via pipeline).
###############################################################################

resource "google_project_service" "secretmanager_api" {
  count = var.enable_api ? 1 : 0

  project            = var.project_id
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_secret_manager_secret" "secrets" {
  for_each  = toset(var.secret_ids)
  project   = var.project_id
  secret_id = each.value

  replication {
    dynamic "auto" {
      for_each = var.replication_type == "auto" ? [1] : []
      content {}
    }
    dynamic "user_managed" {
      for_each = var.replication_type == "user_managed" ? [1] : []
      content {
        dynamic "replicas" {
          for_each = var.replication_locations
          content {
            location = replicas.value
          }
        }
      }
    }
  }

  labels = var.labels

  depends_on = [google_project_service.secretmanager_api]
}

# Flatten: each secret × each IAM binding
locals {
  iam_pairs = flatten([
    for secret in var.secret_ids : [
      for b in var.iam_bindings : {
        key    = "${secret}--${b.role}--${b.member}"
        secret = secret
        role   = b.role
        member = b.member
      }
    ]
  ])
}

resource "google_secret_manager_secret_iam_member" "bindings" {
  for_each = { for p in local.iam_pairs : p.key => p }

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.value.secret].secret_id
  role      = each.value.role
  member    = each.value.member
}
