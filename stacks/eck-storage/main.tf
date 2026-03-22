locals {
  # Sanitize cluster name for GCS bucket naming:
  #   1. Lowercase everything
  #   2. Replace special characters (underscores, dots, spaces, etc.) with hyphens
  #   3. Collapse consecutive hyphens into one
  #   4. Strip leading/trailing hyphens
  _name_lower   = lower(var.cluster_name)
  _name_hyphens = replace(local._name_lower, "/[^a-z0-9-]/", "-")
  _name_clean   = replace(local._name_hyphens, "/-{2,}/", "-")
  cluster_name  = replace(replace(local._name_clean, "/^-+/", ""), "/-+$/", "")
}

# GCS bucket for hot tier snapshots
module "hot_snapshot_bucket" {
  source = "../../modules/gcs-bucket"

  project_id    = var.project_id
  bucket_name   = "${local.cluster_name}-hot-snapshots"
  location      = var.region
  storage_class = var.hot_bucket_storage_class
  force_destroy = var.force_destroy

  enable_versioning = true

  lifecycle_rules = [
    {
      action_type   = "Delete"
      condition_age = var.snapshot_retention_days
    }
  ]

  iam_bindings = [
    {
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:${var.service_account_email}"
    }
  ]
}

# GCS bucket for cold tier snapshots
module "cold_snapshot_bucket" {
  source = "../../modules/gcs-bucket"

  project_id    = var.project_id
  bucket_name   = "${local.cluster_name}-cold-snapshots"
  location      = var.region
  storage_class = var.cold_bucket_storage_class
  force_destroy = var.force_destroy

  enable_versioning = true

  lifecycle_rules = [
    {
      action_type   = "Delete"
      condition_age = var.snapshot_retention_days
    }
  ]

  iam_bindings = [
    {
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:${var.service_account_email}"
    }
  ]
}
