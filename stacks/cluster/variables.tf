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

# Network mode: "default" uses existing default VPC, "custom" creates a new subnet
variable "network_mode" {
  description = "Network mode: 'default' uses the GCP default VPC/subnet, 'custom' creates a dedicated subnet"
  type        = string
  default     = "custom"

  validation {
    condition     = contains(["default", "custom"], var.network_mode)
    error_message = "network_mode must be 'default' or 'custom'."
  }
}

variable "vpc_self_link" {
  description = "Self link of the VPC. Required for custom mode. Ignored in default mode."
  type        = string
  default     = ""
}

# Cluster index for auto-CIDR calculation (1, 2, 3...)
# Each index gets a unique /20 block within 10.0.0.0/8
# Index 1: subnet=10.1.0.0/20, pods=10.1.16.0/20, services=10.1.32.0/20
# Index 2: subnet=10.2.0.0/20, pods=10.2.16.0/20, services=10.2.32.0/20
variable "cluster_index" {
  description = "Cluster index (1-250) for auto-calculating non-overlapping CIDRs. Only used in custom mode."
  type        = number
  default     = 1

  validation {
    condition     = var.cluster_index >= 1 && var.cluster_index <= 250
    error_message = "cluster_index must be between 1 and 250."
  }
}

# Cluster
variable "cluster_name" {
  description = "Name of the GKE cluster. Auto-sanitized: lowercased, special characters (underscores, dots, etc.) replaced with hyphens, consecutive hyphens collapsed, trailing hyphens removed."
  type        = string

  validation {
    condition     = length(var.cluster_name) > 0 && length(var.cluster_name) <= 40
    error_message = "Cluster name must be between 1 and 40 characters."
  }
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
    # GPU configuration (optional)
    gpu_type  = optional(string, "")
    gpu_count = optional(number, 0)
  }))
}

variable "deletion_protection" {
  type    = bool
  default = false
}

# ---- GPU Node Pool (controlled via pipeline parameters) ----
variable "node_pool_type" {
  description = "Which node pools to deploy: standard (tfvars pools only), gpu (GPU pool only), both (tfvars + GPU)"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "gpu", "both"], var.node_pool_type)
    error_message = "node_pool_type must be 'standard', 'gpu', or 'both'."
  }
}

variable "gpu_pool_name" {
  description = "Name of the GPU node pool"
  type        = string
  default     = "gpu-pool"
}

variable "gpu_pool_machine_type" {
  description = "Machine type for GPU nodes"
  type        = string
  default     = "n1-highmem-16"
}

variable "gpu_pool_node_count" {
  description = "Number of GPU nodes (per zone unless gpu_pool_zone is set)"
  type        = number
  default     = 1
}

variable "gpu_pool_zone" {
  description = "Single zone for GPU pool (e.g. us-east1-b). Defaults to us-east1-b for single-node deployment."
  type        = string
  default     = "us-east1-b"
}

variable "gpu_type" {
  description = "GPU accelerator type (e.g. nvidia-tesla-t4, nvidia-tesla-v100, nvidia-tesla-a100)"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_count" {
  description = "Number of GPUs per node"
  type        = number
  default     = 1
}

variable "gpu_pool_disk_size_gb" {
  description = "Disk size in GB for GPU nodes"
  type        = number
  default     = 200
}

# ---- GCS Snapshot Bucket ----
variable "snapshot_bucket_suffix" {
  description = "Suffix appended to cluster name for the GCS snapshot bucket (e.g. bucket-01, hot-snapshots)"
  type        = string
  default     = "bucket-01"
}

variable "snapshot_bucket_storage_class" {
  description = "Storage class for the snapshot bucket"
  type        = string
  default     = "STANDARD"
}

variable "snapshot_retention_days" {
  description = "Days before snapshot objects are auto-deleted (0 to disable)"
  type        = number
  default     = 30
}

variable "snapshot_bucket_force_destroy" {
  description = "Allow snapshot bucket deletion even with objects inside (must be true for clean cluster destroy)"
  type        = bool
  default     = true
}
