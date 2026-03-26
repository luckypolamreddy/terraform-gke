# ============================================================
# pg-us-n-app-259723 - GPU Cluster Configuration (Non-Prod)
# ============================================================
# Standard elastic pool + T4 GPU node pool
# Use this tfvars when you need GPU workloads alongside ECK
# ============================================================

project_id = "pg-us-n-app-259723"
region     = "us-east1"
location   = "us-east1"

# Network
network_mode = "default"

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

# Logging
logging_components    = ["SYSTEM_COMPONENTS", "WORKLOADS"]
monitoring_components = ["SYSTEM_COMPONENTS"]

usage_metering_dataset_id      = ""
enable_network_egress_metering = false

deletion_protection = false

# GCS Snapshot Bucket
snapshot_bucket_suffix        = "bucket-01"
snapshot_bucket_storage_class = "STANDARD"
snapshot_retention_days       = 30
snapshot_bucket_force_destroy = true

# ============================================================
# Node Pools
# ============================================================
# elastic-pool: ES (3) + Kibana + ECK operator + system workloads
# gpu-pool:     T4 GPU workloads (tainted so only GPU pods land here)
# ============================================================

node_pools = [
  {
    name               = "elastic-pool"
    machine_type       = "n1-highmem-16"
    node_count         = 1
    disk_type          = "pd-ssd"
    disk_size_gb       = 500
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels             = {}
    taints             = []
  },
  {
    name               = "gpu-pool"
    machine_type       = "n1-highmem-16"
    node_count         = 1
    disk_type          = "pd-ssd"
    disk_size_gb       = 200
    image_type         = "COS_CONTAINERD"
    enable_autoscaling = false
    min_node_count     = 0
    max_node_count     = 0
    auto_upgrade       = true
    labels = {
      gpu = "true"
    }
    taints = [
      {
        key    = "nvidia.com/gpu"
        value  = "present"
        effect = "NO_SCHEDULE"
      }
    ]
    # NVIDIA Tesla T4 - 1 GPU per node
    gpu_type  = "nvidia-tesla-t4"
    gpu_count = 1
  }
]
