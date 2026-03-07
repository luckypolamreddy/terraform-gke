# =============================================================================
# Project B — Cluster 1 (same node pool design as Project A)
# =============================================================================

project_id   = "gcp-project-b-id"              # CHANGE
region       = "us-east1"
state_bucket = "gcp-project-b-id-tf-state"     # CHANGE

subnet_name = "projb-cluster-1-subnet"
subnet_cidr = "10.20.0.0/20"
subnet_secondary_ranges = [
  { name = "projb-cluster-1-pods",     cidr = "10.20.16.0/20" },
  { name = "projb-cluster-1-services", cidr = "10.20.32.0/20" },
]
subnet_enable_flow_logs = true

cluster_name       = "projb-cluster-1"
cluster_location   = "us-east1"
kubernetes_version = "1.30.5-gke.1443001"
enable_autopilot   = false

pods_range_name     = "projb-cluster-1-pods"
services_range_name = "projb-cluster-1-services"

enable_dns_endpoint        = true
dns_allow_external_traffic = true
enable_ip_endpoint         = false
enable_private_endpoint    = false
enable_private_nodes       = false

maintenance_start_time = "2024-01-06T06:00:00Z"
maintenance_end_time   = "2024-01-06T10:00:00Z"
maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SA"

logging_components    = ["SYSTEM_COMPONENTS", "WORKLOADS"]
monitoring_components = ["SYSTEM_COMPONENTS"]

enable_cost_allocation      = true
enable_usage_metering       = true
disable_http_load_balancing = false
enable_gke_backup_agent     = true
enable_l4_ilb_subsetting    = true
enable_dns_cache            = true
deletion_protection         = true

node_pools = [
  {
    name         = "system-pool"
    machine_type = "e2-standard-4"
    node_count   = 2
    disk_type    = "pd-ssd"
    disk_size_gb = 100
    labels       = { "pool-type" = "system" }
    tags         = ["gke-node", "system"]
  },
  {
    name         = "es-master-pool"
    machine_type = "e2-standard-2"
    node_count   = 3
    disk_type    = "pd-ssd"
    disk_size_gb = 50
    labels       = { "pool-type" = "elasticsearch", "elastic.co/role" = "master" }
    tags         = ["gke-node", "es-master"]
    taints       = [{ key = "elastic.co/role", value = "master", effect = "NO_SCHEDULE" }]
  },
  {
    name         = "es-data-pool"
    machine_type = "n2-highmem-4"
    node_count   = 3
    disk_type    = "pd-ssd"
    disk_size_gb = 500
    labels       = { "pool-type" = "elasticsearch", "elastic.co/role" = "data" }
    tags         = ["gke-node", "es-data"]
    taints       = [{ key = "elastic.co/role", value = "data", effect = "NO_SCHEDULE" }]
  }
]

labels = {
  project      = "project-b"
  cluster-name = "projb-cluster-1"
  managed-by   = "terraform"
  workload     = "elastic-stack"
}
