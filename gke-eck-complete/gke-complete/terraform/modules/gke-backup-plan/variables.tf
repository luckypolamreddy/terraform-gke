variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "location" {
  description = "Backup plan location (must match cluster region)"
  type        = string
}

variable "name" {
  description = "Backup plan name"
  type        = string
}

variable "cluster_id" {
  description = "Full resource ID of the GKE cluster"
  type        = string
}

# ===========================================================================
# Schedule
# ===========================================================================
variable "schedule_type" {
  description = "'rpo' for RPO-based or 'cron' for cron-based schedule"
  type        = string
  default     = "rpo"
  validation {
    condition     = contains(["rpo", "cron"], var.schedule_type)
    error_message = "Must be 'rpo' or 'cron'."
  }
}

variable "rpo_minutes" {
  description = "Target RPO in minutes (1440 = daily). Used when schedule_type = rpo"
  type        = number
  default     = 1440
}

variable "cron_schedule" {
  description = "Cron expression. Used when schedule_type = cron"
  type        = string
  default     = "0 2 * * *"
}

variable "paused" {
  description = "Pause the backup schedule (true = no new backups created)"
  type        = bool
  default     = false
}

# ===========================================================================
# Retention
# ===========================================================================
variable "delete_lock_days" {
  description = "Days backups are locked from deletion. 0 = no lock"
  type        = number
  default     = 0
}

variable "retain_days" {
  description = "Days to keep backups before auto-deletion. 0 = forever"
  type        = number
  default     = 7
}

variable "retention_locked" {
  description = "Lock retention policy (cannot be changed once locked)"
  type        = bool
  default     = false
}

# ===========================================================================
# Scope
# ===========================================================================
variable "scope" {
  description = "Backup scope: 'all', 'selected_namespaces', or 'selected_applications'"
  type        = string
  default     = "all"
  validation {
    condition     = contains(["all", "selected_namespaces", "selected_applications"], var.scope)
    error_message = "Must be 'all', 'selected_namespaces', or 'selected_applications'."
  }
}

variable "namespaces" {
  description = "Namespaces to backup (when scope = selected_namespaces)"
  type        = list(string)
  default     = []
}

variable "applications" {
  description = "Applications to backup (when scope = selected_applications)"
  type = list(object({
    namespace = string
    name      = string
  }))
  default = []
}

variable "include_volumes" {
  description = "Include PersistentVolume data"
  type        = bool
  default     = true
}

variable "include_secrets" {
  description = "Include Kubernetes Secrets"
  type        = bool
  default     = true
}

# ===========================================================================
# Labels
# ===========================================================================
variable "labels" {
  description = "Labels"
  type        = map(string)
  default     = {}
}
