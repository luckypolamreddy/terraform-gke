variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Globally unique bucket name"
  type        = string
}

variable "location" {
  description = "Bucket location (region or multi-region)"
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "STANDARD, NEARLINE, COLDLINE, ARCHIVE"
  type        = string
  default     = "STANDARD"
}

variable "force_destroy" {
  description = "Allow deletion even with objects inside"
  type        = bool
  default     = false
}

variable "uniform_bucket_level_access" {
  description = "Enable uniform bucket-level access"
  type        = bool
  default     = true
}

variable "public_access_prevention" {
  description = "Public access prevention: inherited or enforced"
  type        = string
  default     = "enforced"
}

variable "versioning" {
  description = "Enable object versioning"
  type        = bool
  default     = true
}

variable "lifecycle_rules" {
  description = "Bucket lifecycle rules"
  type = list(object({
    action                = string
    target_storage_class  = optional(string, null)
    age_days              = optional(number, null)
    num_newer_versions    = optional(number, null)
    with_state            = optional(string, null)
    matches_storage_class = optional(list(string), null)
  }))
  default = []
}

variable "retention_period_seconds" {
  description = "Retention period in seconds (null = no retention policy)"
  type        = number
  default     = null
}

variable "retention_policy_locked" {
  description = "Lock retention policy"
  type        = bool
  default     = false
}

variable "iam_bindings" {
  description = "IAM bindings: list of {role, member}"
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
