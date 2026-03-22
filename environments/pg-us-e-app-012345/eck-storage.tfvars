# ============================================================
# pg-us-e-app-012345 - ECK Storage Configuration (Prod)
# ============================================================
# GCS buckets for hot/cold snapshot repositories
# cluster_name is passed at pipeline runtime via -var=cluster_name=xxx
# ============================================================

project_id            = "pg-us-e-app-012345"
region                = "us-east1"
service_account_email = "terraform-sa@pg-us-e-app-012345.iam.gserviceaccount.com"

# Hot snapshots: STANDARD class for fast restore
hot_bucket_storage_class = "STANDARD"

# Cold snapshots: NEARLINE for cost savings (accessed < 1x/month)
cold_bucket_storage_class = "NEARLINE"

# Auto-delete snapshots after 90 days
snapshot_retention_days = 90

force_destroy = false
