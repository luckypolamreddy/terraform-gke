# ============================================================
# Project A - Foundation Configuration
# ============================================================

project_id            = "project-a-id"
region                = "us-east1"
service_account_email = "terraform-sa@project-a-id.iam.gserviceaccount.com"

# VPC
vpc_name        = "project-a-vpc"
routing_mode    = "REGIONAL"
vpc_description = "VPC for Project A GKE clusters"

# GCS Bucket (for ECK snapshots and app configs)
gcs_bucket_name       = "project-a-eck-snapshots"
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
