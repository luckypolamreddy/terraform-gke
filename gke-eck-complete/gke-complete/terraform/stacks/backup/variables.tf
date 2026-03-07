# ===========================================================================
# Core
# ===========================================================================
variable "project_id" { type = string }
variable "region" { type = string; default = "us-east1" }
variable "credentials" { type = string; sensitive = true; default = null }
variable "state_bucket" { type = string }
variable "cluster_name" { description = "Cluster name (used to locate cluster remote state)"; type = string }
variable "backup_plan_name" { type = string }
variable "labels" { type = map(string); default = {} }

# ===========================================================================
# Schedule
# ===========================================================================
variable "schedule_type" { type = string; default = "rpo" }
variable "rpo_minutes" { type = number; default = 1440 }
variable "cron_schedule" { type = string; default = "0 2 * * *" }
variable "paused" { type = bool; default = false }

# ===========================================================================
# Retention
# ===========================================================================
variable "delete_lock_days" { type = number; default = 0 }
variable "retain_days" { type = number; default = 7 }
variable "retention_locked" { type = bool; default = false }

# ===========================================================================
# Scope
# ===========================================================================
variable "scope" { type = string; default = "all" }
variable "namespaces" { type = list(string); default = [] }
variable "applications" {
  type = list(object({ namespace = string; name = string }))
  default = []
}
variable "include_volumes" { type = bool; default = true }
variable "include_secrets" { type = bool; default = true }
