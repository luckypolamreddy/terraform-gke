variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "location" {
  description = "Backup plan location"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster (used to build cluster_id and backup_plan_name). Auto-sanitized: lowercased, special characters replaced with hyphens."
  type        = string

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 40
    error_message = "Cluster name must be between 1 and 40 characters."
  }
}

variable "backup_namespaces" {
  description = "Namespaces to backup"
  type        = list(string)
  default     = ["elastic-system", "elastic-stack"]
}

variable "rpo_minutes" {
  description = "RPO in minutes (1440 = daily)"
  type        = number
  default     = 1440
}

variable "backup_retain_days" {
  description = "Days to retain backups"
  type        = number
  default     = 7
}

variable "include_volume_data" {
  type    = bool
  default = true
}

variable "include_secrets" {
  type    = bool
  default = true
}

variable "paused" {
  type    = bool
  default = false
}
