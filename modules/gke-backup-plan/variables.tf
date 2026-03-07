variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "backup_plan_name" {
  description = "Name of the backup plan"
  type        = string
}

variable "location" {
  description = "Location for the backup plan"
  type        = string
}

variable "cluster_id" {
  description = "Full resource ID of the GKE cluster"
  type        = string
}

variable "backup_namespaces" {
  description = "List of namespaces to backup"
  type        = list(string)
  default     = ["elastic-system", "elastic-stack"]
}

variable "rpo_minutes" {
  description = "Target RPO in minutes (1440 = daily)"
  type        = number
  default     = 1440
}

variable "backup_retain_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "include_volume_data" {
  description = "Include volume data in backups"
  type        = bool
  default     = true
}

variable "include_secrets" {
  description = "Include secrets in backups"
  type        = bool
  default     = true
}

variable "paused" {
  description = "Whether the backup schedule is paused"
  type        = bool
  default     = false
}
