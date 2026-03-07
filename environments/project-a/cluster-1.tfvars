# ============================================================
# Project A - Cluster 1 Configuration
# ============================================================

project_id = "project-a-id"
region     = "us-east1"
location   = "us-east1"

# Network (VPC self_link from foundation output)
vpc_self_link = "projects/project-a-id/global/networks/project-a-vpc"
subnet_name   = "project-a-cluster-1-subnet"
subnet_cidr   = "10.10.0.0/20"
pods_cidr     = "10.10.16.0/20"
services_cidr = "10.10.32.0/20"

# Cluster
cluster_name       = "project-a-cluster-1"
kubernetes_version = "1.30"

# Access - DNS only, no public IP
enable_dns_access_only = true

# Maintenance - Saturday 1 AM EST (6 AM UTC)
maintenance_start_time = "2024-01-06T06:00:00Z"
maintenance_end_time   = "2024-01-06T10:00:00Z"
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
# Node Pools
# ============================================================
# Pool 1: controlplane-pool  - General workloads + ECK operator + Kibana
# Pool 2: elastic-master-pool - Elasticsearch master nodes (tainted)
# Pool 3: elastic-data-pool   - Elasticsearch data nodes (tainted)
# ============================================================

node_pools = [
  {
    name               = "controlplane-pool"
    machine_type       = "n1-highmem-16"
    node_count         = 3
    disk_type          = "pd-ssd"
    disk_size_gb       = 100
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      role = "controlplane"
    }
    taints = []
  },
  {
    name               = "elastic-master-pool"
    machine_type       = "e2-standard-4"
    node_count         = 3
    disk_type          = "pd-ssd"
    disk_size_gb       = 100
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      "elastic-role" = "master"
    }
    taints = [
      {
        key    = "elastic-role"
        value  = "master"
        effect = "NO_SCHEDULE"
      }
    ]
  },
  {
    name               = "elastic-data-pool"
    machine_type       = "n1-highmem-16"
    node_count         = 3
    disk_type          = "pd-ssd"
    disk_size_gb       = 500
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
