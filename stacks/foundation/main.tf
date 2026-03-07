module "vpc" {
  source = "../../modules/vpc"

  project_id   = var.project_id
  vpc_name     = var.vpc_name
  routing_mode = var.routing_mode
  description  = var.vpc_description
}

module "gcs_bucket" {
  source = "../../modules/gcs-bucket"

  project_id        = var.project_id
  bucket_name       = var.gcs_bucket_name
  location          = var.region
  storage_class     = var.gcs_storage_class
  force_destroy     = var.gcs_force_destroy
  enable_versioning = var.gcs_enable_versioning
  lifecycle_rules   = var.gcs_lifecycle_rules

  iam_bindings = [
    {
      role   = "roles/storage.objectAdmin"
      member = "serviceAccount:${var.service_account_email}"
    }
  ]
}

module "secret_manager" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secret_ids = var.secret_ids
  labels     = var.secret_labels

  iam_bindings = [
    for secret_id in var.secret_ids : {
      secret_id = secret_id
      role      = "roles/secretmanager.secretAccessor"
      member    = "serviceAccount:${var.service_account_email}"
    }
  ]
}
