# ============================================================
# pg-us-e-app-012345 - Foundation Configuration
# ============================================================

project_id            = "pg-us-e-app-012345"
region                = "us-east1"
service_account_email = "terraform-sa@pg-us-e-app-012345.iam.gserviceaccount.com"

# VPC
vpc_name        = "pg-us-e-app-012345-vpc"
routing_mode    = "REGIONAL"
vpc_description = "VPC for pg-us-e-app-012345 GKE clusters"

# GCS Bucket
gcs_bucket_name       = "pg-us-e-app-012345-eck-snapshots"
gcs_storage_class     = "STANDARD"
gcs_force_destroy     = false
gcs_enable_versioning = true
gcs_lifecycle_rules   = []

# Secret Manager (disabled — not needed for current deployment)
enable_secret_manager = false
secret_ids            = []
secret_labels         = {}
