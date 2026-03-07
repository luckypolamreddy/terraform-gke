###############################################################################
# GKE Cluster Module - Generic
# Every setting is variable-driven. Supports Standard & Autopilot,
# private & public, any addon combination, any node pool configuration.
###############################################################################

# ---------- BigQuery Dataset for Usage Metering (conditional) ----------
resource "google_bigquery_dataset" "usage_metering" {
  count = var.enable_usage_metering ? 1 : 0

  dataset_id    = replace("${var.name}_usage_metering", "-", "_")
  project       = var.project_id
  location      = var.region
  friendly_name = "GKE Usage Metering - ${var.name}"
  description   = "Usage metering dataset for cluster ${var.name}"

  default_table_expiration_ms = var.bq_default_table_expiration_ms
  labels                      = var.labels
}

# ---------- GKE Cluster ----------
resource "google_container_cluster" "this" {
  provider = google-beta

  name     = var.name
  project  = var.project_id
  location = var.location

  # --- Cluster type ---
  enable_autopilot = var.enable_autopilot

  # --- Kubernetes version ---
  min_master_version = var.kubernetes_version

  # --- Networking ---
  network    = var.network_self_link
  subnetwork = var.subnet_self_link

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # --- Control plane endpoints ---
  control_plane_endpoints_config {
    dns_endpoint_config {
      enabled                = var.enable_dns_endpoint
      allow_external_traffic = var.dns_allow_external_traffic
    }
    ip_endpoints_config {
      enabled = var.enable_ip_endpoint
    }
  }

  # --- Private cluster (always present, values decide behavior) ---
  private_cluster_config {
    enable_private_endpoint = var.enable_private_endpoint
    enable_private_nodes    = var.enable_private_nodes
    master_ipv4_cidr_block  = var.enable_private_nodes ? var.master_ipv4_cidr_block : null
  }

  # --- Master authorized networks (conditional) ---
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  # --- Maintenance window ---
  maintenance_policy {
    recurring_window {
      start_time = var.maintenance_start_time
      end_time   = var.maintenance_end_time
      recurrence = var.maintenance_recurrence
    }
  }

  # --- Logging ---
  logging_config {
    enable_components = var.logging_components
  }

  # --- Monitoring ---
  monitoring_config {
    enable_components = var.monitoring_components
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  # --- Cost management ---
  cost_management_config {
    enabled = var.enable_cost_allocation
  }

  # --- Usage metering (conditional) ---
  dynamic "resource_usage_export_config" {
    for_each = var.enable_usage_metering ? [1] : []
    content {
      enable_network_egress_metering       = var.enable_network_egress_metering
      enable_resource_consumption_metering = var.enable_resource_consumption_metering
      bigquery_destination {
        dataset_id = google_bigquery_dataset.usage_metering[0].dataset_id
      }
    }
  }

  # --- Addons ---
  addons_config {
    http_load_balancing {
      disabled = var.disable_http_load_balancing
    }
    horizontal_pod_autoscaling {
      disabled = var.disable_horizontal_pod_autoscaling
    }
    network_policy_config {
      disabled = var.disable_network_policy
    }
    gke_backup_agent_config {
      enabled = var.enable_gke_backup_agent
    }
    dns_cache_config {
      enabled = var.enable_dns_cache
    }
  }

  # --- L4 ILB subsetting ---
  enable_l4_ilb_subsetting = var.enable_l4_ilb_subsetting

  # --- Cluster autoscaling (node auto-provisioning) ---
  cluster_autoscaling {
    enabled = var.enable_cluster_autoscaling
  }

  # --- Security ---
  deletion_protection = var.deletion_protection

  binary_authorization {
    evaluation_mode = var.binary_authorization_mode
  }

  # --- Remove default node pool ---
  remove_default_node_pool = true
  initial_node_count       = 1

  # --- Labels ---
  resource_labels = var.labels

  lifecycle {
    ignore_changes = [
      node_pool,
      initial_node_count,
    ]
  }
}

# ---------- Node Pools ----------
resource "google_container_node_pool" "pools" {
  for_each = { for np in var.node_pools : np.name => np }

  name     = each.value.name
  project  = var.project_id
  location = var.location
  cluster  = google_container_cluster.this.name

  node_count = each.value.enable_autoscaling ? null : each.value.node_count

  # --- Per-pool autoscaling (conditional) ---
  dynamic "autoscaling" {
    for_each = each.value.enable_autoscaling ? [1] : []
    content {
      min_node_count  = each.value.min_node_count
      max_node_count  = each.value.max_node_count
      location_policy = each.value.location_policy
    }
  }

  node_config {
    machine_type    = each.value.machine_type
    disk_type       = each.value.disk_type
    disk_size_gb    = each.value.disk_size_gb
    image_type      = each.value.image_type
    service_account = each.value.service_account
    oauth_scopes    = each.value.oauth_scopes
    spot            = each.value.spot
    preemptible     = each.value.preemptible

    metadata = merge(
      { "disable-legacy-endpoints" = "true" },
      each.value.metadata
    )

    labels = merge(var.labels, each.value.labels)
    tags   = each.value.tags

    shielded_instance_config {
      enable_secure_boot          = each.value.enable_secure_boot
      enable_integrity_monitoring = each.value.enable_integrity_monitoring
    }

    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    dynamic "guest_accelerator" {
      for_each = each.value.gpu_type != "" ? [1] : []
      content {
        type  = each.value.gpu_type
        count = each.value.gpu_count
      }
    }
  }

  management {
    auto_repair  = each.value.auto_repair
    auto_upgrade = each.value.auto_upgrade
  }

  upgrade_settings {
    max_surge       = each.value.max_surge
    max_unavailable = each.value.max_unavailable
  }
}
