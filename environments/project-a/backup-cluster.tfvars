# ============================================================
# Project A - Backup Plan Configuration (shared by all clusters)
# ============================================================
# cluster_name is provided at pipeline runtime
# cluster_id is auto-generated as projects/<project>/locations/<location>/clusters/<cluster_name>
# backup_plan_name is auto-generated as <cluster_name>-backup

project_id = "project-a-id"
region     = "us-east1"
location   = "us-east1"

# Backup only elastic namespaces
backup_namespaces = ["elastic-system", "elastic-stack"]

# Daily RPO (1440 minutes = 24 hours)
rpo_minutes = 1440

# Retain backups for 7 days
backup_retain_days = 7

include_volume_data = true
include_secrets     = true
paused              = false
