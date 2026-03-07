variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "routing_mode" {
  description = "Routing mode for the VPC (REGIONAL or GLOBAL)"
  type        = string
  default     = "REGIONAL"
}

variable "description" {
  description = "Description of the VPC"
  type        = string
  default     = ""
}
