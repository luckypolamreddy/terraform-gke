###############################################################################
# Foundation Stack — PERSISTENT (never destroyed with clusters)
# Creates: VPC, GCS bucket, Secret Manager secrets, enables APIs.
###############################################################################

# ---- Enable APIs ----
resource "google_project_service" "apis" {
  for_each = toset(var.enable_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ---- VPC ----
module "vpc" {
  source = "../../modules/vpc"

  project_id              = var.project_id
  name                    = var.vpc_name
  auto_create_subnetworks = var.vpc_auto_create_subnetworks
  routing_mode            = var.vpc_routing_mode
  description             = var.vpc_description
  mtu                     = var.vpc_mtu
  firewall_rules          = var.vpc_firewall_rules

  depends_on = [google_project_service.apis]
}

# ---- GCS Bucket ----
module "gcs_bucket" {
  source = "../../modules/gcs-bucket"

  project_id                  = var.project_id
  name                        = var.gcs_name
  location                    = var.gcs_location
  storage_class               = var.gcs_storage_class
  force_destroy               = var.gcs_force_destroy
  uniform_bucket_level_access = var.gcs_uniform_access
  public_access_prevention    = var.gcs_public_access_prevention
  versioning                  = var.gcs_versioning
  lifecycle_rules             = var.gcs_lifecycle_rules
  retention_period_seconds    = var.gcs_retention_period_seconds
  iam_bindings                = var.gcs_iam_bindings
  labels                      = var.labels

  depends_on = [google_project_service.apis]
}

# ---- Secret Manager ----
module "secret_manager" {
  source = "../../modules/secret-manager"

  project_id            = var.project_id
  enable_api            = true
  secret_ids            = var.secret_ids
  replication_type      = var.secret_replication_type
  replication_locations = var.secret_replication_locations
  iam_bindings          = var.secret_iam_bindings
  labels                = var.labels

  depends_on = [google_project_service.apis]
}
