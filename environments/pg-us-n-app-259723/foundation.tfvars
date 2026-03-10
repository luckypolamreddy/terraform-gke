# ============================================================
# pg-us-n-app-259723 - Foundation Configuration (VPC only)
# GCS bucket is managed by the cluster pipeline (02-cluster.yml)
# ============================================================

project_id            = "pg-us-n-app-259723"
region                = "us-east1"
service_account_email = "terraform-sa@pg-us-n-app-259723.iam.gserviceaccount.com"

# VPC
vpc_name        = "pg-us-n-app-259723-vpc"
routing_mode    = "REGIONAL"
vpc_description = "VPC for pg-us-n-app-259723 GKE clusters"
