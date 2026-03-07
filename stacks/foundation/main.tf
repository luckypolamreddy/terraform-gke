module "vpc" {
  source = "../../modules/vpc"
  count  = var.enable_vpc ? 1 : 0

  project_id   = var.project_id
  vpc_name     = var.vpc_name
  routing_mode = var.routing_mode
  description  = var.vpc_description
}

module "gcs_bucket" {
  source = "../../modules/gcs-bucket"
  count  = var.enable_gcs ? 1 : 0

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
  count  = var.enable_secret_manager ? 1 : 0

  project_id = var.project_id
  secret_ids = var.secret_ids
  labels     = var.secret_labels

  # IAM bindings removed — the Terraform SA lacks secretmanager.secrets.setIamPolicy permission.
  # Grant secret access manually via GCP Console or ask a project admin to run:
  #   gcloud secrets add-iam-policy-binding <secret-id> \
  #     --member="serviceAccount:<gke-sa-email>" \
  #     --role="roles/secretmanager.secretAccessor" \
  #     --project=<project-id>
  iam_bindings = []
}
