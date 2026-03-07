variable "enable_vpc" {
  description = "Enable VPC creation"
  type        = bool
  default     = true
}

variable "enable_gcs" {
  description = "Enable GCS bucket creation"
  type        = bool
  default     = true
}

variable "enable_secret_manager" {
  description = "Enable Secret Manager creation"
  type        = bool
  default     = true
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for IAM bindings"
  type        = string
}

# VPC variables
variable "vpc_name" {
  description = "VPC network name"
  type        = string
}

variable "routing_mode" {
  description = "VPC routing mode"
  type        = string
  default     = "REGIONAL"
}

variable "vpc_description" {
  description = "VPC description"
  type        = string
  default     = "VPC for GKE clusters"
}

# GCS Bucket variables
variable "gcs_bucket_name" {
  description = "GCS bucket name for app configs and ECK snapshots"
  type        = string
}

variable "gcs_storage_class" {
  description = "Storage class for GCS bucket"
  type        = string
  default     = "STANDARD"
}

variable "gcs_force_destroy" {
  description = "Allow bucket deletion with objects inside"
  type        = bool
  default     = false
}

variable "gcs_enable_versioning" {
  description = "Enable versioning on GCS bucket"
  type        = bool
  default     = true
}

variable "gcs_lifecycle_rules" {
  description = "Lifecycle rules for GCS bucket"
  type = list(object({
    action_type          = string
    action_storage_class = optional(string)
    condition_age        = number
  }))
  default = []
}

# Secret Manager variables
variable "secret_ids" {
  description = "List of secret IDs to create in Secret Manager"
  type        = list(string)
  default     = ["kibana-credentials"]
}

variable "secret_labels" {
  description = "Labels for Secret Manager secrets"
  type        = map(string)
  default     = {}
}
