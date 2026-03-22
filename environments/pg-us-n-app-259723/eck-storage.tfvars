# ============================================================
# pg-us-n-app-259723 - ECK Storage Configuration (Non-Prod)
# ============================================================
# GCS buckets for hot/cold snapshot repositories
# cluster_name is passed at pipeline runtime via -var=cluster_name=xxx
# ============================================================

project_id            = "pg-us-n-app-259723"
region                = "us-east1"
service_account_email = "terraform-sa@pg-us-n-app-259723.iam.gserviceaccount.com"

# Hot snapshots: STANDARD class for fast restore
hot_bucket_storage_class = "STANDARD"

# Cold snapshots: NEARLINE for cost savings (accessed < 1x/month)
cold_bucket_storage_class = "NEARLINE"

# Auto-delete snapshots after 30 days for non-prod
snapshot_retention_days = 30

force_destroy = true
