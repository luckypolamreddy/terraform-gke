# ============================================================
# pg-us-e-app-012345 - Foundation Configuration (VPC only)
# GCS bucket is managed by the cluster pipeline (02-cluster.yml)
# ============================================================

project_id            = "pg-us-e-app-012345"
region                = "us-east1"
service_account_email = "terraform-sa@pg-us-e-app-012345.iam.gserviceaccount.com"

# VPC
vpc_name        = "pg-us-e-app-012345-vpc"
routing_mode    = "REGIONAL"
vpc_description = "VPC for pg-us-e-app-012345 GKE clusters"
