resource "google_container_cluster" "cluster" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.location

  network    = var.network
  subnetwork = var.subnetwork

  # Standard cluster - remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  min_master_version = var.kubernetes_version

  # DNS-based endpoint access (no public IP for control plane)
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  # Not a private cluster, not private nodes
  private_cluster_config {
    enable_private_endpoint = var.enable_dns_access_only
    enable_private_nodes    = false
  }

  # VPC-native networking (required for GKE)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_secondary_range_name
    services_secondary_range_name = var.services_secondary_range_name
  }

  networking_mode = "VPC_NATIVE"

  # Maintenance window - weekly on specified day
  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }

  # Addons
  addons_config {
    http_load_balancing {
      disabled = !var.enable_http_load_balancing
    }

    gke_backup_agent_config {
      enabled = var.enable_backup
    }
  }

  # Logging - only workloads
  logging_config {
    enable_components = var.logging_components
  }

  # Monitoring
  monitoring_config {
    enable_components = var.monitoring_components
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  # Cost allocation
  cost_management_config {
    enabled = var.enable_cost_allocation
  }

  # Usage metering
  dynamic "resource_usage_export_config" {
    for_each = var.usage_metering_dataset_id != "" ? [1] : []
    content {
      enable_network_egress_metering       = var.enable_network_egress_metering
      enable_resource_consumption_metering = true
      bigquery_destination {
        dataset_id = var.usage_metering_dataset_id
      }
    }
  }

  # Disable deletion protection for terraform management
  deletion_protection = var.deletion_protection
}

# Node pools
resource "google_container_node_pool" "pools" {
  for_each = { for pool in var.node_pools : pool.name => pool }

  name     = each.value.name
  project  = var.project_id
  location = var.location
  cluster  = google_container_cluster.cluster.name

  node_count = each.value.node_count

  # Autoscaling
  dynamic "autoscaling" {
    for_each = each.value.enable_autoscaling ? [1] : []
    content {
      min_node_count = each.value.min_node_count
      max_node_count = each.value.max_node_count
    }
  }

  node_config {
    machine_type = each.value.machine_type
    disk_type    = each.value.disk_type
    disk_size_gb = each.value.disk_size_gb
    image_type   = each.value.image_type

    oauth_scopes = var.node_oauth_scopes

    labels = each.value.labels

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = each.value.auto_upgrade
  }
}
