###############################################################################
# Cluster Stack — DELETABLE (destroying removes cluster + subnet)
# Reads VPC from foundation remote state.
###############################################################################

# If machine_type_override is set at pipeline runtime, replace machine_type
# on ALL node pools. Otherwise use what's in .tfvars unchanged.
locals {
  effective_node_pools = var.machine_type_override != "" ? [
    for np in var.node_pools : merge(np, {
      machine_type = var.machine_type_override
    })
  ] : var.node_pools
}

data "terraform_remote_state" "foundation" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "foundation"
  }
}

# ---- Subnet (one per cluster, deleted with cluster) ----
module "subnet" {
  source = "../../modules/subnet"

  project_id               = var.project_id
  region                   = var.region
  name                     = var.subnet_name
  network_self_link        = data.terraform_remote_state.foundation.outputs.vpc_self_link
  ip_cidr_range            = var.subnet_cidr
  description              = var.subnet_description
  private_ip_google_access = var.subnet_private_google_access
  purpose                  = var.subnet_purpose
  secondary_ranges         = var.subnet_secondary_ranges
  enable_flow_logs         = var.subnet_enable_flow_logs
  flow_logs_interval       = var.subnet_flow_logs_interval
  flow_logs_sampling       = var.subnet_flow_logs_sampling
  flow_logs_metadata       = var.subnet_flow_logs_metadata
}

# ---- GKE Cluster ----
module "gke" {
  source = "../../modules/gke-cluster"

  project_id         = var.project_id
  name               = var.cluster_name
  location           = var.cluster_location
  region             = var.region
  kubernetes_version = var.kubernetes_version
  enable_autopilot   = var.enable_autopilot

  # Networking
  network_self_link   = data.terraform_remote_state.foundation.outputs.vpc_self_link
  subnet_self_link    = module.subnet.self_link
  pods_range_name     = var.pods_range_name
  services_range_name = var.services_range_name

  # Control plane access
  enable_dns_endpoint        = var.enable_dns_endpoint
  dns_allow_external_traffic = var.dns_allow_external_traffic
  enable_ip_endpoint         = var.enable_ip_endpoint

  # Private cluster
  enable_private_endpoint    = var.enable_private_endpoint
  enable_private_nodes       = var.enable_private_nodes
  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  master_authorized_networks = var.master_authorized_networks

  # Maintenance
  maintenance_start_time = var.maintenance_start_time
  maintenance_end_time   = var.maintenance_end_time
  maintenance_recurrence = var.maintenance_recurrence

  # Logging & monitoring
  logging_components        = var.logging_components
  monitoring_components     = var.monitoring_components
  enable_managed_prometheus = var.enable_managed_prometheus

  # Cost management
  enable_cost_allocation               = var.enable_cost_allocation
  enable_usage_metering                = var.enable_usage_metering
  enable_network_egress_metering       = var.enable_network_egress_metering
  enable_resource_consumption_metering = var.enable_resource_consumption_metering

  # Addons
  disable_http_load_balancing        = var.disable_http_load_balancing
  disable_horizontal_pod_autoscaling = var.disable_horizontal_pod_autoscaling
  disable_network_policy             = var.disable_network_policy
  enable_gke_backup_agent            = var.enable_gke_backup_agent
  enable_dns_cache                   = var.enable_dns_cache
  enable_l4_ilb_subsetting           = var.enable_l4_ilb_subsetting

  # Autoscaling & security
  enable_cluster_autoscaling = var.enable_cluster_autoscaling
  deletion_protection        = var.deletion_protection
  binary_authorization_mode  = var.binary_authorization_mode

  # Node pools — with runtime machine_type override if provided
  node_pools = local.effective_node_pools

  # Labels
  labels = var.labels
}
