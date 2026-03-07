# ===========================================================================
# Core
# ===========================================================================
variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east1"
}

variable "credentials" {
  type      = string
  sensitive = true
  default   = null
}

variable "enable_apis" {
  description = "GCP APIs to enable"
  type        = list(string)
  default = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "gkebackup.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "bigquery.googleapis.com",
  ]
}

variable "labels" {
  type    = map(string)
  default = {}
}

# ===========================================================================
# VPC
# ===========================================================================
variable "vpc_name" {
  type = string
}

variable "vpc_auto_create_subnetworks" {
  type    = bool
  default = false
}

variable "vpc_routing_mode" {
  type    = string
  default = "REGIONAL"
}

variable "vpc_description" {
  type    = string
  default = ""
}

variable "vpc_mtu" {
  type    = number
  default = 1460
}

variable "vpc_firewall_rules" {
  type = list(object({
    name        = string
    description = optional(string, "")
    direction   = optional(string, "INGRESS")
    priority    = optional(number, 1000)
    disabled    = optional(bool, false)
    allow = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    deny = optional(list(object({
      protocol = string
      ports    = optional(list(string))
    })), [])
    ranges      = optional(list(string), [])
    target_tags = optional(list(string), null)
    source_tags = optional(list(string), null)
  }))
  default = []
}

# ===========================================================================
# GCS Bucket
# ===========================================================================
variable "gcs_name" {
  type = string
}

variable "gcs_location" {
  type    = string
  default = "US-EAST1"
}

variable "gcs_storage_class" {
  type    = string
  default = "STANDARD"
}

variable "gcs_force_destroy" {
  type    = bool
  default = false
}

variable "gcs_uniform_access" {
  type    = bool
  default = true
}

variable "gcs_public_access_prevention" {
  type    = string
  default = "enforced"
}

variable "gcs_versioning" {
  type    = bool
  default = true
}

variable "gcs_lifecycle_rules" {
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

variable "gcs_retention_period_seconds" {
  type    = number
  default = null
}

variable "gcs_iam_bindings" {
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}

# ===========================================================================
# Secret Manager
# ===========================================================================
variable "secret_ids" {
  type    = list(string)
  default = []
}

variable "secret_replication_type" {
  type    = string
  default = "auto"
}

variable "secret_replication_locations" {
  type    = list(string)
  default = []
}

variable "secret_iam_bindings" {
  type = list(object({
    role   = string
    member = string
  }))
  default = []
}
