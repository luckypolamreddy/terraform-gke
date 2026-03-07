# ============================================================
# Project B - Foundation Configuration
# ============================================================

project_id            = "project-b-id"
region                = "us-east1"
service_account_email = "terraform-sa@project-b-id.iam.gserviceaccount.com"

# VPC
vpc_name        = "project-b-vpc"
routing_mode    = "REGIONAL"
vpc_description = "VPC for Project B GKE clusters"

# GCS Bucket
gcs_bucket_name       = "project-b-eck-snapshots"
gcs_storage_class     = "STANDARD"
gcs_force_destroy     = false
gcs_enable_versioning = true
gcs_lifecycle_rules   = []

# Secret Manager
secret_ids   = ["kibana-credentials", "elastic-credentials"]
secret_labels = {
  environment = "production"
  team        = "platform"
}
