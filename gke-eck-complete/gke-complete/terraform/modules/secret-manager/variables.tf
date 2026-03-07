variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "enable_api" {
  description = "Enable Secret Manager API (false if already enabled)"
  type        = bool
  default     = true
}

variable "secret_ids" {
  description = "List of secret IDs to create"
  type        = list(string)
  default     = []
}

variable "replication_type" {
  description = "'auto' or 'user_managed'"
  type        = string
  default     = "auto"
  validation {
    condition     = contains(["auto", "user_managed"], var.replication_type)
    error_message = "Must be 'auto' or 'user_managed'."
  }
}

variable "replication_locations" {
  description = "Replication locations (when replication_type = user_managed)"
  type        = list(string)
  default     = []
}

variable "iam_bindings" {
  description = "IAM bindings applied to ALL secrets: list of {role, member}"
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}

variable "labels" {
  description = "Labels"
  type        = map(string)
  default     = {}
}
