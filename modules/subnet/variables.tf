variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "vpc_self_link" {
  description = "Self link of the VPC network"
  type        = string
}

variable "ip_cidr_range" {
  description = "Primary IP CIDR range for the subnet"
  type        = string
}

variable "private_ip_google_access" {
  description = "Enable private Google access"
  type        = bool
  default     = true
}

variable "secondary_ip_ranges" {
  description = "Secondary IP ranges for pods and services"
  type = list(object({
    range_name    = string
    ip_cidr_range = string
  }))
  default = []
}
