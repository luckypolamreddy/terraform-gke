resource "google_storage_bucket" "bucket" {
  name                        = var.bucket_name
  project                     = var.project_id
  location                    = var.location
  storage_class               = var.storage_class
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  dynamic "versioning" {
    for_each = var.enable_versioning ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action_type
        storage_class = lookup(lifecycle_rule.value, "action_storage_class", null)
      }
      condition {
        age = lifecycle_rule.value.condition_age
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Grant service account access to the bucket
resource "google_storage_bucket_iam_member" "member" {
  for_each = { for binding in var.iam_bindings : "${binding.role}-${binding.member}" => binding }

  bucket = google_storage_bucket.bucket.name
  role   = each.value.role
  member = each.value.member
}
