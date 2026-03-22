variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name (used as bucket prefix)"
  type        = string
}

variable "service_account_email" {
  description = "Service account email to grant bucket access"
  type        = string
}

variable "hot_bucket_storage_class" {
  description = "Storage class for the hot snapshot bucket"
  type        = string
  default     = "STANDARD"
}

variable "cold_bucket_storage_class" {
  description = "Storage class for the cold snapshot bucket"
  type        = string
  default     = "NEARLINE"
}

variable "snapshot_retention_days" {
  description = "Days before snapshot objects are auto-deleted"
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Allow bucket deletion even with objects inside"
  type        = bool
  default     = false
}
