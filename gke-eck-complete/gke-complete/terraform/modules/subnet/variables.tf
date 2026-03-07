variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "name" {
  description = "Subnet name"
  type        = string
}

variable "network_self_link" {
  description = "VPC network self link"
  type        = string
}

variable "ip_cidr_range" {
  description = "Primary CIDR range"
  type        = string
}

variable "description" {
  description = "Subnet description"
  type        = string
  default     = ""
}

variable "private_ip_google_access" {
  description = "Enable private Google access"
  type        = bool
  default     = true
}

variable "purpose" {
  description = "Subnet purpose (PRIVATE, REGIONAL_MANAGED_PROXY, etc.)"
  type        = string
  default     = "PRIVATE"
}

variable "stack_type" {
  description = "IP stack type: IPV4_ONLY or IPV4_IPV6"
  type        = string
  default     = "IPV4_ONLY"
}

variable "secondary_ranges" {
  description = "List of secondary IP ranges"
  type = list(object({
    name = string
    cidr = string
  }))
  default = []
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = false
}

variable "flow_logs_interval" {
  description = "Flow logs aggregation interval"
  type        = string
  default     = "INTERVAL_5_SEC"
}

variable "flow_logs_sampling" {
  description = "Flow logs sampling rate (0.0 to 1.0)"
  type        = number
  default     = 0.5
}

variable "flow_logs_metadata" {
  description = "Flow logs metadata: INCLUDE_ALL_METADATA, EXCLUDE_ALL_METADATA, CUSTOM_METADATA"
  type        = string
  default     = "INCLUDE_ALL_METADATA"
}

variable "flow_logs_filter" {
  description = "Flow logs filter expression (empty = no filter)"
  type        = string
  default     = "true"
}
