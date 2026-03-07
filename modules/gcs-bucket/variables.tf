variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "bucket_name" {
  description = "Name of the GCS bucket"
  type        = string
}

variable "location" {
  description = "GCS bucket location"
  type        = string
}

variable "storage_class" {
  description = "Storage class for the bucket"
  type        = string
  default     = "STANDARD"
}

variable "force_destroy" {
  description = "Allow bucket deletion even with objects inside"
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Enable object versioning"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for the bucket"
  type = list(object({
    action_type          = string
    action_storage_class = optional(string)
    condition_age        = number
  }))
  default = []
}

variable "iam_bindings" {
  description = "IAM bindings for the bucket"
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}
