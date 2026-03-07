variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "VPC network name"
  type        = string
}

variable "auto_create_subnetworks" {
  description = "Auto-create subnets per region"
  type        = bool
  default     = false
}

variable "routing_mode" {
  description = "REGIONAL or GLOBAL"
  type        = string
  default     = "REGIONAL"
}

variable "description" {
  description = "VPC description"
  type        = string
  default     = ""
}

variable "mtu" {
  description = "MTU for the VPC (1460 or 1500)"
  type        = number
  default     = 1460
}

variable "firewall_rules" {
  description = "List of firewall rules"
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
