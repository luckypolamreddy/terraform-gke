# ============================================================
# pg-us-e-app-012345 - Backup Plan Configuration (shared by all clusters)
# ============================================================
# cluster_name is provided at pipeline runtime
# cluster_id is auto-generated as projects/<project>/locations/<location>/clusters/<cluster_name>
# backup_plan_name is auto-generated as <cluster_name>-backup-01

project_id = "pg-us-e-app-012345"
region     = "us-east1"
location   = "us-east1"

backup_namespaces = ["elastic-system", "elastic-stack"]
rpo_minutes        = 1440
backup_retain_days = 7
include_volume_data = true
include_secrets     = true
paused              = false
