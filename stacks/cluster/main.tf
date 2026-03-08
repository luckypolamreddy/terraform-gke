locals {
  subnet_name = "${var.cluster_name}-subnet-01"
}

module "subnet" {
  source = "../../modules/subnet"

  project_id               = var.project_id
  subnet_name              = local.subnet_name
  region                   = var.region
  vpc_self_link            = var.vpc_self_link
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  secondary_ip_ranges = [
    {
      range_name    = "${local.subnet_name}-pods"
      ip_cidr_range = var.pods_cidr
    },
    {
      range_name    = "${local.subnet_name}-services"
      ip_cidr_range = var.services_cidr
    }
  ]
}

module "gke_cluster" {
  source = "../../modules/gke-cluster"

  project_id         = var.project_id
  cluster_name       = var.cluster_name
  location           = var.location
  network            = var.vpc_self_link
  subnetwork         = module.subnet.subnet_self_link
  kubernetes_version = var.kubernetes_version

  pods_secondary_range_name     = "${local.subnet_name}-pods"
  services_secondary_range_name = "${local.subnet_name}-services"

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

  # Node pools
  node_pools = var.node_pools

  deletion_protection = var.deletion_protection

  depends_on = [module.subnet]
}
