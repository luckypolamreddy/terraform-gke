# ============================================================
# pg-us-e-app-012345 - Cluster Configuration (Prod)
# ============================================================

project_id = "pg-us-e-app-012345"
region     = "us-east1"
location   = "us-east1"

# Network — Custom VPC for prod (dedicated subnets per cluster)
# cluster_index auto-calculates unique CIDRs: 10.<index>.0.0/20
# Pass -var=cluster_index=N at pipeline runtime (1, 2, 3...)
network_mode  = "custom"
vpc_self_link = "projects/pg-us-e-app-012345/global/networks/pg-us-e-app-012345-vpc"
# cluster_index is passed as pipeline parameter (no hardcoded CIDRs)

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
# Node Pools - Prod (3 nodes across 3 zones)
# ============================================================
# Single pool: n1-highmem-16 - ES (3) + Kibana (3) + ECK operator + system
# ============================================================

node_pools = [
  {
    name               = "elastic-pool"
    machine_type       = "n1-highmem-16"
    node_count         = 1
    disk_type          = "pd-ssd"
    disk_size_gb       = 1000
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {}
    taints = []
  }
]
