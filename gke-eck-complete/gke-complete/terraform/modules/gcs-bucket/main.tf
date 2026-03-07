###############################################################################
# GCS Bucket Module - Generic
###############################################################################

resource "google_storage_bucket" "this" {
  name          = var.name
  project       = var.project_id
  location      = var.location
  storage_class = var.storage_class
  force_destroy = var.force_destroy

  uniform_bucket_level_access = var.uniform_bucket_level_access
  public_access_prevention    = var.public_access_prevention

  versioning {
    enabled = var.versioning
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action
        storage_class = lifecycle_rule.value.target_storage_class
      }
      condition {
        age                   = lifecycle_rule.value.age_days
        num_newer_versions    = lifecycle_rule.value.num_newer_versions
        with_state            = lifecycle_rule.value.with_state
        matches_storage_class = lifecycle_rule.value.matches_storage_class
      }
    }
  }

  dynamic "retention_policy" {
    for_each = var.retention_period_seconds != null ? [1] : []
    content {
      retention_period = var.retention_period_seconds
      is_locked        = var.retention_policy_locked
    }
  }

  labels = var.labels
}

resource "google_storage_bucket_iam_member" "bindings" {
  for_each = { for b in var.iam_bindings : "${b.role}--${b.member}" => b }

  bucket = google_storage_bucket.this.name
  role   = each.value.role
  member = each.value.member
}
