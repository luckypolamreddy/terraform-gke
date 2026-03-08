# ============================================================
# pg-us-n-app-259723 - Cluster Configuration (Non-Prod)
# ============================================================

project_id = "pg-us-n-app-259723"
region     = "us-east1"
location   = "us-east1"

# Network (subnet_name is auto-generated as <cluster_name>-subnet-01)
vpc_self_link = "projects/pg-us-n-app-259723/global/networks/pg-us-n-app-259723-vpc"
subnet_cidr   = "10.10.0.0/20"
pods_cidr     = "10.10.16.0/20"
services_cidr = "10.10.32.0/20"

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

# Logging - workloads only
logging_components    = ["SYSTEM_COMPONENTS", "WORKLOADS"]
monitoring_components = ["SYSTEM_COMPONENTS"]

# Usage metering (set BigQuery dataset ID, leave empty to disable)
usage_metering_dataset_id      = ""
enable_network_egress_metering = false

deletion_protection = false

# ============================================================
# Node Pools - Non-Prod (7 nodes total)
# ============================================================
# Pool 1: system-pool          - ECK operator + kube-system (1 node)
# Pool 2: master-kibana-pool   - ES master (3) + Kibana (2) = 5 pods on 3 nodes
# Pool 3: data-pool            - ES data nodes (3)
# ============================================================

node_pools = [
  {
    name               = "system-pool"
    machine_type       = "e2-standard-2"
    node_count         = 1
    disk_type          = "pd-standard"
    disk_size_gb       = 50
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      "role" = "system"
    }
    taints = []
  },
  {
    name               = "master-kibana-pool"
    machine_type       = "n1-highmem-2"
    node_count         = 3
    disk_type          = "pd-ssd"
    disk_size_gb       = 100
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      "elastic-role" = "master-kibana"
    }
    taints = [
      {
        key    = "elastic-role"
        value  = "master-kibana"
        effect = "NO_SCHEDULE"
      }
    ]
  },
  {
    name               = "data-pool"
    machine_type       = "n1-highmem-8"
    node_count         = 3
    disk_type          = "pd-ssd"
    disk_size_gb       = 1000
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      "elastic-role" = "data"
    }
    taints = [
      {
        key    = "elastic-role"
        value  = "data"
        effect = "NO_SCHEDULE"
      }
    ]
  }
]
