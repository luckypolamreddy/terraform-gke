# ============================================================
# pg-us-n-app-259723 - Cluster Configuration (shared by all clusters)
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

# Maintenance - Saturday 1 AM EST (6 AM UTC) to 1 PM EST (6 PM UTC)
maintenance_start_time = "2024-01-06T06:00:00Z"
maintenance_end_time   = "2024-01-06T18:00:00Z"
maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SA"

# Features
enable_http_load_balancing = true
enable_backup              = true
enable_cost_allocation     = true
enable_managed_prometheus  = true

# Logging - workloads only
logging_components    = ["WORKLOADS"]
monitoring_components = ["SYSTEM_COMPONENTS"]

# Usage metering (set BigQuery dataset ID, leave empty to disable)
usage_metering_dataset_id      = "gke_usage_metering"
enable_network_egress_metering = false

deletion_protection = false

# ============================================================
# Node Pools (6 nodes total)
# ============================================================
# Pool 1: master-kibana-pool - ES master (2) + Kibana (1) = 3 nodes
# Pool 2: data-pool          - ES data nodes (3)
# ============================================================

node_pools = [
  {
    name               = "master-kibana-pool"
    machine_type       = "n1-highmem-4"
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
    machine_type       = "n1-highmem-16"
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
