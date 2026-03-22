# ============================================================
# pg-us-e-app-012345 - HA Cluster Configuration (Prod)
# ============================================================
# ECK HA: 3 node pools (general + hot + cold)
# Estimated cost: ~$1,311/month (vs $1,458 single-pool)
# ============================================================

project_id = "pg-us-e-app-012345"
region     = "us-east1"
location   = "us-east1"

# Network — Custom VPC for prod (dedicated subnets per cluster)
# cluster_index auto-calculates unique CIDRs: 10.<index>.0.0/20
# Pass -var=cluster_index=N at pipeline runtime (1, 2, 3...)
network_mode  = "custom"
vpc_self_link = "projects/pg-us-e-app-012345/global/networks/pg-us-e-app-012345-vpc"

# Cluster (cluster_name is provided at pipeline runtime)
kubernetes_version = "1.30"

# Maintenance - Saturday (weekly)
maintenance = {
  start_time = "2026-02-21T00:00:00Z"
  end_time   = "2026-02-22T00:00:00Z"
  recurrence = "FREQ=WEEKLY;BYDAY=SA"
}

# Features
enable_http_load_balancing = true
enable_backup              = true
enable_cost_allocation     = true
enable_managed_prometheus  = true

logging_components    = ["SYSTEM_COMPONENTS", "WORKLOADS"]
monitoring_components = ["SYSTEM_COMPONENTS"]

usage_metering_dataset_id      = ""
enable_network_egress_metering = false

deletion_protection = false

# ============================================================
# Node Pools - HA (3 pools across 3 zones)
# ============================================================
# general-pool: ES masters (3), Kibana (2), ECK operator, beats
#   - NO taints (ECK operator needs to schedule here freely)
# hot-pool:     ES hot data nodes (3) - active indexing/search
#   - Tainted: only ES hot pods schedule here
# cold-pool:    ES cold data nodes (3) - infrequent access
#   - Tainted: only ES cold pods schedule here
# ============================================================

node_pools = [
  {
    name               = "general-pool"
    machine_type       = "n1-standard-4"
    node_count         = 1
    disk_type          = "pd-ssd"
    disk_size_gb       = 100
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      node-pool = "general-pool"
    }
    taints = []
  },
  {
    name               = "hot-pool"
    machine_type       = "n1-highmem-8"
    node_count         = 1
    disk_type          = "pd-ssd"
    disk_size_gb       = 500
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      node-pool = "hot-pool"
    }
    taints = [
      {
        key    = "elastic-role"
        value  = "hot"
        effect = "NO_SCHEDULE"
      }
    ]
  },
  {
    name               = "cold-pool"
    machine_type       = "n1-standard-4"
    node_count         = 1
    disk_type          = "pd-standard"
    disk_size_gb       = 1000
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      node-pool = "cold-pool"
    }
    taints = [
      {
        key    = "elastic-role"
        value  = "cold"
        effect = "NO_SCHEDULE"
      }
    ]
  }
]
