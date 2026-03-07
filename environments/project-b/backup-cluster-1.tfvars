# ============================================================
# Project B - Backup Plan for Cluster 1
# ============================================================

project_id       = "project-b-id"
region           = "us-east1"
location         = "us-east1"
backup_plan_name = "project-b-cluster-1-backup"

cluster_id = "projects/project-b-id/locations/us-east1/clusters/project-b-cluster-1"

backup_namespaces  = ["elastic-system", "elastic-stack"]
rpo_minutes        = 1440
backup_retain_days = 7
include_volume_data = true
include_secrets     = true
paused              = false
