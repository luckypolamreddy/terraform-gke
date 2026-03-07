# ===========================================================================
# Core
# ===========================================================================
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Cluster name"
  type        = string
}

variable "location" {
  description = "Cluster location (region for regional, zone for zonal)"
  type        = string
}

variable "region" {
  description = "GCP region (used for BigQuery dataset location)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the control plane"
  type        = string
}

variable "enable_autopilot" {
  description = "true = Autopilot, false = Standard"
  type        = bool
  default     = false
}

# ===========================================================================
# Networking
# ===========================================================================
variable "network_self_link" {
  description = "VPC self link"
  type        = string
}

variable "subnet_self_link" {
  description = "Subnet self link"
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods"
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services"
  type        = string
}

# ===========================================================================
# Control Plane Endpoints
# ===========================================================================
variable "enable_dns_endpoint" {
  description = "Enable DNS-based control plane access"
  type        = bool
  default     = true
}

variable "dns_allow_external_traffic" {
  description = "Allow external traffic to DNS endpoint"
  type        = bool
  default     = true
}

variable "enable_ip_endpoint" {
  description = "Enable IP-based control plane access"
  type        = bool
  default     = true
}

# ===========================================================================
# Private Cluster
# ===========================================================================
variable "enable_private_endpoint" {
  description = "Restrict control plane to private endpoint only"
  type        = bool
  default     = false
}

variable "enable_private_nodes" {
  description = "Nodes get internal IPs only"
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR for control plane VPC peering (required when enable_private_nodes = true)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_networks" {
  description = "CIDRs allowed to reach the control plane IP endpoint"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

# ===========================================================================
# Maintenance
# ===========================================================================
variable "maintenance_start_time" {
  description = "Maintenance window start (RFC 3339)"
  type        = string
  default     = "2024-01-06T06:00:00Z"
}

variable "maintenance_end_time" {
  description = "Maintenance window end (RFC 3339)"
  type        = string
  default     = "2024-01-06T10:00:00Z"
}

variable "maintenance_recurrence" {
  description = "RRULE recurrence for maintenance window"
  type        = string
  default     = "FREQ=WEEKLY;BYDAY=SA"
}

# ===========================================================================
# Logging & Monitoring
# ===========================================================================
variable "logging_components" {
  description = "Components to log: SYSTEM_COMPONENTS, WORKLOADS, APISERVER, SCHEDULER, CONTROLLER_MANAGER"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "monitoring_components" {
  description = "Components to monitor"
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS"]
}

variable "enable_managed_prometheus" {
  description = "Enable Managed Prometheus"
  type        = bool
  default     = true
}

# ===========================================================================
# Cost Management
# ===========================================================================
variable "enable_cost_allocation" {
  description = "Enable GKE cost allocation"
  type        = bool
  default     = false
}

variable "enable_usage_metering" {
  description = "Enable GKE usage metering to BigQuery"
  type        = bool
  default     = false
}

variable "enable_network_egress_metering" {
  description = "Meter network egress"
  type        = bool
  default     = true
}

variable "enable_resource_consumption_metering" {
  description = "Meter resource consumption"
  type        = bool
  default     = true
}

variable "bq_default_table_expiration_ms" {
  description = "BigQuery table expiration (null = never)"
  type        = number
  default     = null
}

# ===========================================================================
# Addons
# ===========================================================================
variable "disable_http_load_balancing" {
  description = "Disable HTTP LB addon"
  type        = bool
  default     = false
}

variable "disable_horizontal_pod_autoscaling" {
  description = "Disable HPA addon"
  type        = bool
  default     = false
}

variable "disable_network_policy" {
  description = "Disable Network Policy addon"
  type        = bool
  default     = true
}

variable "enable_gke_backup_agent" {
  description = "Enable GKE Backup agent on nodes"
  type        = bool
  default     = false
}

variable "enable_dns_cache" {
  description = "Enable NodeLocal DNSCache"
  type        = bool
  default     = false
}

variable "enable_l4_ilb_subsetting" {
  description = "Enable L4 ILB subsetting"
  type        = bool
  default     = false
}

# ===========================================================================
# Autoscaling & Security
# ===========================================================================
variable "enable_cluster_autoscaling" {
  description = "Enable node auto-provisioning"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Prevent accidental cluster deletion"
  type        = bool
  default     = true
}

variable "binary_authorization_mode" {
  description = "DISABLED or PROJECT_SINGLETON_POLICY_ENFORCE"
  type        = string
  default     = "DISABLED"
}

# ===========================================================================
# Node Pools
# ===========================================================================
variable "node_pools" {
  description = "List of node pool configurations"
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

    # Autoscaling
    enable_autoscaling = optional(bool, false)
    min_node_count     = optional(number, 0)
    max_node_count     = optional(number, 0)
    location_policy    = optional(string, "BALANCED")

    # Management
    auto_repair  = optional(bool, true)
    auto_upgrade = optional(bool, true)
    max_surge       = optional(number, 1)
    max_unavailable = optional(number, 0)

    # Security
    enable_secure_boot          = optional(bool, true)
    enable_integrity_monitoring = optional(bool, true)

    # Taints
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])

    # GPU (set gpu_type = "" to skip)
    gpu_type  = optional(string, "")
    gpu_count = optional(number, 0)
  }))
  default = []
}

# ===========================================================================
# Labels
# ===========================================================================
variable "labels" {
  description = "Labels applied to cluster and nodes"
  type        = map(string)
  default     = {}
}
