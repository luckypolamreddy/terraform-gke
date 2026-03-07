# ============================================================
# Project A - Backup Plan for Cluster 1
# ============================================================

project_id       = "project-a-id"
region           = "us-east1"
location         = "us-east1"
backup_plan_name = "project-a-cluster-1-backup"

# Cluster ID (from cluster stack output)
cluster_id = "projects/project-a-id/locations/us-east1/clusters/project-a-cluster-1"

# Backup only elastic namespaces
backup_namespaces = ["elastic-system", "elastic-stack"]

# Daily RPO (1440 minutes = 24 hours)
rpo_minutes = 1440

# Retain backups for 7 days
backup_retain_days = 7

include_volume_data = true
include_secrets     = true
paused              = false
