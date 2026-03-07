# ===========================================================================
# Core
# ===========================================================================
variable "project_id" { type = string }
variable "region" { type = string; default = "us-east1" }
variable "credentials" { type = string; sensitive = true; default = null }
variable "state_bucket" { description = "GCS bucket holding Terraform state"; type = string }
variable "labels" { type = map(string); default = {} }

# ===========================================================================
# Runtime overrides (passed via pipeline -var, empty = use tfvars value)
# ===========================================================================
variable "machine_type_override" {
  description = "Override machine_type for ALL node pools. Empty = use tfvars."
  type        = string
  default     = ""
}

# ===========================================================================
# Subnet
# ===========================================================================
variable "subnet_name" { type = string }
variable "subnet_cidr" { type = string }
variable "subnet_description" { type = string; default = "" }
variable "subnet_private_google_access" { type = bool; default = true }
variable "subnet_purpose" { type = string; default = "PRIVATE" }

variable "subnet_secondary_ranges" {
  type = list(object({
    name = string
    cidr = string
  }))
}

variable "subnet_enable_flow_logs" { type = bool; default = false }
variable "subnet_flow_logs_interval" { type = string; default = "INTERVAL_5_SEC" }
variable "subnet_flow_logs_sampling" { type = number; default = 0.5 }
variable "subnet_flow_logs_metadata" { type = string; default = "INCLUDE_ALL_METADATA" }

# ===========================================================================
# GKE Cluster
# ===========================================================================
variable "cluster_name" { type = string }
variable "cluster_location" { type = string; default = "us-east1" }
variable "kubernetes_version" { type = string }
variable "enable_autopilot" { type = bool; default = false }

# --- Networking ---
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }

# --- Control plane endpoints ---
variable "enable_dns_endpoint" { type = bool; default = true }
variable "dns_allow_external_traffic" { type = bool; default = true }
variable "enable_ip_endpoint" { type = bool; default = true }

# --- Private cluster ---
variable "enable_private_endpoint" { type = bool; default = false }
variable "enable_private_nodes" { type = bool; default = false }
variable "master_ipv4_cidr_block" { type = string; default = "172.16.0.0/28" }
variable "master_authorized_networks" {
  type = list(object({ cidr_block = string; display_name = string }))
  default = []
}

# --- Maintenance ---
variable "maintenance_start_time" { type = string; default = "2024-01-06T06:00:00Z" }
variable "maintenance_end_time" { type = string; default = "2024-01-06T10:00:00Z" }
variable "maintenance_recurrence" { type = string; default = "FREQ=WEEKLY;BYDAY=SA" }

# --- Logging & monitoring ---
variable "logging_components" { type = list(string); default = ["SYSTEM_COMPONENTS", "WORKLOADS"] }
variable "monitoring_components" { type = list(string); default = ["SYSTEM_COMPONENTS"] }
variable "enable_managed_prometheus" { type = bool; default = true }

# --- Cost ---
variable "enable_cost_allocation" { type = bool; default = false }
variable "enable_usage_metering" { type = bool; default = false }
variable "enable_network_egress_metering" { type = bool; default = true }
variable "enable_resource_consumption_metering" { type = bool; default = true }

# --- Addons ---
variable "disable_http_load_balancing" { type = bool; default = false }
variable "disable_horizontal_pod_autoscaling" { type = bool; default = false }
variable "disable_network_policy" { type = bool; default = true }
variable "enable_gke_backup_agent" { type = bool; default = false }
variable "enable_dns_cache" { type = bool; default = false }
variable "enable_l4_ilb_subsetting" { type = bool; default = false }

# --- Autoscaling & security ---
variable "enable_cluster_autoscaling" { type = bool; default = false }
variable "deletion_protection" { type = bool; default = true }
variable "binary_authorization_mode" { type = string; default = "DISABLED" }

# --- Node pools ---
variable "node_pools" {
  type = list(object({
    name            = string
    machine_type    = string
    node_count      = number
    disk_type       = string
    disk_size_gb    = number
    image_type      = optional(string, "COS_CONTAINERD")
    service_account = optional(string, null)
    oauth_scopes    = optional(list(string), ["https://www.googleapis.com/auth/cloud-platform"])
    spot            = optional(bool, false)
    preemptible     = optional(bool, false)
    metadata        = optional(map(string), {})
    labels          = optional(map(string), {})
    tags            = optional(list(string), [])
    enable_autoscaling = optional(bool, false)
    min_node_count     = optional(number, 0)
    max_node_count     = optional(number, 0)
    location_policy    = optional(string, "BALANCED")
    auto_repair        = optional(bool, true)
    auto_upgrade       = optional(bool, true)
    max_surge          = optional(number, 1)
    max_unavailable    = optional(number, 0)
    enable_secure_boot          = optional(bool, true)
    enable_integrity_monitoring = optional(bool, true)
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    gpu_type  = optional(string, "")
    gpu_count = optional(number, 0)
  }))
}
