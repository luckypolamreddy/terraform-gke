# ============================================================
# pg-us-n-app-259723 - Foundation Configuration
# ============================================================

project_id            = "pg-us-n-app-259723"
region                = "us-east1"
service_account_email = "terraform-sa@pg-us-n-app-259723.iam.gserviceaccount.com"

# VPC
vpc_name        = "pg-us-n-app-259723-vpc"
routing_mode    = "REGIONAL"
vpc_description = "VPC for pg-us-n-app-259723 GKE clusters"

# GCS Bucket (for ECK snapshots and app configs)
gcs_bucket_name       = "pg-us-n-app-259723-eck-snapshots"
gcs_storage_class     = "STANDARD"
gcs_force_destroy     = false
gcs_enable_versioning = true
gcs_lifecycle_rules   = []

# Secret Manager (disabled — not needed for current deployment)
enable_secret_manager = false
secret_ids            = []
secret_labels         = {}
