variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "Name of the GKE cluster. Must be pre-sanitized: only lowercase letters, numbers, and hyphens."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.cluster_name)) && length(var.cluster_name) <= 40
    error_message = "Cluster name must start with a lowercase letter, end with a letter or number, contain only lowercase letters, numbers, and hyphens, and be at most 40 characters."
  }
}

variable "location" {
  description = "GKE cluster location (region or zone)"
  type        = string
}

variable "network" {
  description = "VPC network self link"
  type        = string
}

variable "subnetwork" {
  description = "Subnet self link"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
}

variable "pods_secondary_range_name" {
  description = "Name of the secondary IP range for pods"
  type        = string
}

variable "services_secondary_range_name" {
  description = "Name of the secondary IP range for services"
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

# Addons
variable "enable_http_load_balancing" {
  description = "Enable HTTP load balancing addon"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable GKE Backup agent on the cluster"
  type        = bool
  default     = true
}

# Logging
variable "logging_components" {
  description = "Logging components to enable"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

# Monitoring
variable "monitoring_components" {
  description = "Monitoring components to enable"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS"]
}

variable "enable_managed_prometheus" {
  description = "Enable managed Prometheus"
  type        = bool
  default     = true
}

# Cost management
variable "enable_cost_allocation" {
  description = "Enable cost allocation tracking"
  type        = bool
  default     = true
}

# Usage metering
variable "usage_metering_dataset_id" {
  description = "BigQuery dataset ID for usage metering (empty to disable)"
  type        = string
  default     = ""
}

variable "enable_network_egress_metering" {
  description = "Enable network egress metering"
  type        = bool
  default     = false
}

# Node pools
variable "node_pools" {
  description = "List of node pool configurations"
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

variable "node_oauth_scopes" {
  description = "OAuth scopes for node service accounts"
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform",
  ]
}

variable "deletion_protection" {
  description = "Enable deletion protection on the cluster"
  type        = bool
  default     = false
}
