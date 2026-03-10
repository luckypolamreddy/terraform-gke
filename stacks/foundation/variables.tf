variable "enable_vpc" {
  description = "Enable VPC creation"
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
