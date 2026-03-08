variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "location" {
  description = "GKE cluster location"
  type        = string
}

# Network
variable "vpc_self_link" {
  description = "Self link of the VPC (from foundation stack output)"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR range for the subnet"
  type        = string
}

variable "pods_cidr" {
  description = "CIDR range for pods secondary range"
  type        = string
}

variable "services_cidr" {
  description = "CIDR range for services secondary range"
  type        = string
}

# Cluster
variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "maintenance" {
  type = object({
    start_time = string
    end_time   = string
    recurrence = string
  })
  description = "Maintenance window configuration"
  default = {
    start_time = "2026-02-21T00:00:00Z"
    end_time   = "2026-02-22T00:00:00Z"
    recurrence = "FREQ=WEEKLY;BYDAY=SA"
  }
}

# Features
variable "enable_http_load_balancing" {
  type    = bool
  default = true
}

variable "enable_backup" {
  type    = bool
  default = true
}

variable "enable_cost_allocation" {
  type    = bool
  default = true
}

variable "enable_managed_prometheus" {
  type    = bool
  default = true
}

variable "logging_components" {
  type    = list(string)
  default = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "monitoring_components" {
  type    = list(string)
  default = ["SYSTEM_COMPONENTS"]
}

variable "usage_metering_dataset_id" {
  type    = string
  default = ""
}

variable "enable_network_egress_metering" {
  type    = bool
  default = false
}

# Node pools
variable "node_pools" {
  description = "Node pool configurations"
  type = list(object({
    name               = string
    machine_type       = string
    node_count         = number
    node_locations     = optional(list(string), [])
    disk_type          = string
    disk_size_gb       = number
    image_type         = string
    enable_autoscaling = bool
    min_node_count     = number
    max_node_count     = number
    auto_upgrade       = bool
    labels             = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}

variable "deletion_protection" {
  type    = bool
  default = false
}
