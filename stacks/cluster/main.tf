locals {
  # Sanitize cluster name for GKE:
  #   1. Lowercase everything
  #   2. Replace special characters (underscores, dots, spaces, etc.) with hyphens
  #   3. Collapse consecutive hyphens into one
  #   4. Strip leading/trailing hyphens
  _name_lower   = lower(var.cluster_name)
  _name_hyphens = replace(local._name_lower, "/[^a-z0-9-]/", "-")
  _name_clean   = replace(local._name_hyphens, "/-{2,}/", "-")
  cluster_name  = replace(replace(local._name_clean, "/^-+/", ""), "/-+$/", "")
  subnet_name  = "${local.cluster_name}-subnet-01"
  is_default   = var.network_mode == "default"

  # Auto-calculate CIDRs based on cluster_index (custom mode only)
  # Each cluster_index gets its own /20 blocks in the 10.x.0.0 space:
  #   Index 1: subnet=10.1.0.0/20,  pods=10.1.16.0/20,  services=10.1.32.0/20
  #   Index 2: subnet=10.2.0.0/20,  pods=10.2.16.0/20,  services=10.2.32.0/20
  #   Index 3: subnet=10.3.0.0/20,  pods=10.3.16.0/20,  services=10.3.32.0/20
  # This gives each cluster 4096 IPs for nodes, 4096 for pods, 4096 for services
  subnet_cidr   = "10.${var.cluster_index}.0.0/20"
  pods_cidr     = "10.${var.cluster_index}.16.0/20"
  services_cidr = "10.${var.cluster_index}.32.0/20"

  # Default mode: use "default" network and subnet
  network    = local.is_default ? "default" : var.vpc_self_link
  subnetwork = local.is_default ? "default" : module.subnet[0].subnet_self_link

  # Node pool type: "standard" = tfvars pools only, "gpu" = GPU pool only, "both" = tfvars + GPU
  include_standard = var.node_pool_type == "standard" || var.node_pool_type == "both"
  include_gpu      = var.node_pool_type == "gpu" || var.node_pool_type == "both"

  # GPU node pool definition
  gpu_node_pool = local.include_gpu ? [
    {
      name               = var.gpu_pool_name
      machine_type       = var.gpu_pool_machine_type
      node_count         = var.gpu_pool_node_count
      node_locations     = var.gpu_pool_zone != "" ? [var.gpu_pool_zone] : []
      disk_type          = "pd-ssd"
      disk_size_gb       = var.gpu_pool_disk_size_gb
      image_type         = "COS_CONTAINERD"
      enable_autoscaling = false
      min_node_count     = 0
      max_node_count     = 0
      auto_upgrade       = true
      labels             = { gpu = "true" }
      taints = [
        {
          key    = "nvidia.com/gpu"
          value  = "present"
          effect = "NO_SCHEDULE"
        }
      ]
      gpu_type  = var.gpu_type
      gpu_count = var.gpu_count
    }
  ] : []

  # Standard pools from tfvars (filter out gpu-pool name to prevent duplicates)
  standard_pools = local.include_standard ? [for pool in var.node_pools : pool if pool.name != var.gpu_pool_name] : []

  # Final merged pool list
  all_node_pools = concat(local.standard_pools, local.gpu_node_pool)
}

# Custom subnet — only created in "custom" mode
module "subnet" {
  source = "../../modules/subnet"
  count  = local.is_default ? 0 : 1

  project_id               = var.project_id
  subnet_name              = local.subnet_name
  region                   = var.region
  vpc_self_link            = var.vpc_self_link
  ip_cidr_range            = local.subnet_cidr
  private_ip_google_access = true

  secondary_ip_ranges = [
    {
      range_name    = "${local.subnet_name}-pods"
      ip_cidr_range = local.pods_cidr
    },
    {
      range_name    = "${local.subnet_name}-services"
      ip_cidr_range = local.services_cidr
    }
  ]
}

module "gke_cluster" {
  source = "../../modules/gke-cluster"

  project_id         = var.project_id
  cluster_name       = local.cluster_name
  location           = var.location
  network            = local.network
  subnetwork         = local.subnetwork
  kubernetes_version = var.kubernetes_version

  # In default mode, GKE auto-allocates pod/service CIDRs (no secondary ranges needed)
  # In custom mode, use the named secondary ranges from our subnet
  pods_secondary_range_name     = local.is_default ? "" : "${local.subnet_name}-pods"
  services_secondary_range_name = local.is_default ? "" : "${local.subnet_name}-services"

  # Maintenance
  maintenance = var.maintenance

  # Features
  enable_http_load_balancing = var.enable_http_load_balancing
  enable_backup              = var.enable_backup
  enable_cost_allocation     = var.enable_cost_allocation
  enable_managed_prometheus  = var.enable_managed_prometheus

  # Logging
  logging_components    = var.logging_components
  monitoring_components = var.monitoring_components

  # Usage metering
  usage_metering_dataset_id      = var.usage_metering_dataset_id
  enable_network_egress_metering = var.enable_network_egress_metering

  # Node pools (includes GPU pool when enable_gpu=true)
  node_pools = local.all_node_pools

  deletion_protection = var.deletion_protection

  depends_on = [module.subnet]
}

# ---- GCS Snapshot Bucket (deployed with the cluster) ----
module "snapshot_bucket" {
  source = "../../modules/gcs-bucket"

  project_id    = var.project_id
  bucket_name   = "${local.cluster_name}-${var.snapshot_bucket_suffix}"
  location      = var.region
  storage_class = var.snapshot_bucket_storage_class
  force_destroy = var.snapshot_bucket_force_destroy

  enable_versioning = true

  lifecycle_rules = var.snapshot_retention_days > 0 ? [
    {
      action_type   = "Delete"
      condition_age = var.snapshot_retention_days
    }
  ] : []
}
