# =============================================================================
# Project A — Cluster 1 (ECK-ready GKE cluster)
#
# NODE POOL DESIGN:
# ┌──────────────────────────────────────────────────────────────────────────┐
# │ Pool             │ Machine       │ Nodes │ Taint               │ Runs   │
# ├──────────────────┼───────────────┼───────┼─────────────────────┼────────┤
# │ system-pool      │ e2-standard-4 │   2   │ (none)              │ Kibana │
# │                  │ 4 vCPU, 16GB  │       │                     │ Oper.  │
# │                  │               │       │                     │ Jobs   │
# ├──────────────────┼───────────────┼───────┼─────────────────────┼────────┤
# │ es-master-pool   │ e2-standard-2 │   3   │ elastic.co/role=    │ ES     │
# │                  │ 2 vCPU, 8GB   │       │ master:NoSchedule   │ Master │
# ├──────────────────┼───────────────┼───────┼─────────────────────┼────────┤
# │ es-data-pool     │ n2-highmem-4  │   3   │ elastic.co/role=    │ ES     │
# │                  │ 4 vCPU, 32GB  │       │ data:NoSchedule     │ Data   │
# └──────────────────────────────────────────────────────────────────────────┘
#
# WHY THESE MACHINE TYPES:
#   e2-standard-4  — Cost-efficient for system workloads + Kibana
#   e2-standard-2  — ES masters need minimal resources (no data, no queries)
#   n2-highmem-4   — ES data nodes need HIGH MEMORY for JVM heap (16g heap
#                    on 32GB = 50% ratio, leaves room for OS file cache)
#
# TAINT STRATEGY:
#   System pool has NO taints — default landing zone for everything
#   ES pools have taints — ONLY pods with matching tolerations get scheduled
#   This prevents non-ES workloads from consuming ES-dedicated resources
# =============================================================================

project_id   = "gcp-project-a-id"              # CHANGE
region       = "us-east1"
state_bucket = "gcp-project-a-id-tf-state"     # CHANGE

# =============================================================================
# Subnet
# =============================================================================
subnet_name = "proja-cluster-1-subnet"
subnet_cidr = "10.10.0.0/20"

subnet_secondary_ranges = [
  { name = "proja-cluster-1-pods",     cidr = "10.10.16.0/20" },
  { name = "proja-cluster-1-services", cidr = "10.10.32.0/20" },
]

subnet_enable_flow_logs = true

# =============================================================================
# GKE Cluster
# =============================================================================
cluster_name       = "proja-cluster-1"
cluster_location   = "us-east1"                            # Regional cluster
kubernetes_version = "1.30.5-gke.1443001"                  # Override at pipeline runtime
enable_autopilot   = false                                 # Standard cluster

pods_range_name     = "proja-cluster-1-pods"
services_range_name = "proja-cluster-1-services"

# --- Control plane access ---
enable_dns_endpoint        = true
dns_allow_external_traffic = true
enable_ip_endpoint         = false

enable_private_endpoint = false
enable_private_nodes    = false

# --- Maintenance: Saturday 1 AM EST = 06:00 UTC ---
maintenance_start_time = "2024-01-06T06:00:00Z"
maintenance_end_time   = "2024-01-06T10:00:00Z"
maintenance_recurrence = "FREQ=WEEKLY;BYDAY=SA"

# --- Logging & monitoring ---
logging_components    = ["SYSTEM_COMPONENTS", "WORKLOADS"]
monitoring_components = ["SYSTEM_COMPONENTS"]

# --- Cost management ---
enable_cost_allocation = true
enable_usage_metering  = true

# --- Addons ---
disable_http_load_balancing = false
enable_gke_backup_agent     = true         # Required for GKE backup plans
enable_l4_ilb_subsetting    = true
enable_dns_cache            = true         # NodeLocal DNSCache helps ES lookups

# --- Security ---
deletion_protection = true

# =============================================================================
# NODE POOLS — Purpose-built for ECK
# =============================================================================
node_pools = [

  # ── SYSTEM POOL ──────────────────────────────────────────────────────────
  # Runs: kube-system, ECK operator, Kibana (2 pods), snapshot jobs,
  #       credentials sync, index setup jobs
  # No taints = default landing zone for anything without tolerations
  {
    name               = "system-pool"
    machine_type       = "e2-standard-4"      # 4 vCPU, 16GB RAM
    node_count         = 2
    disk_type          = "pd-ssd"
    disk_size_gb       = 100
    enable_autoscaling = false
    labels = {
      "pool-type"    = "system"
      "workload"     = "system-and-kibana"
    }
    tags = ["gke-node", "system"]
  },

  # ── ES MASTER POOL ──────────────────────────────────────────────────────
  # Runs: 3 dedicated ES master nodes (no data, no queries)
  # Taints ensure ONLY ES master pods land here
  # e2-standard-2: masters don't need much — they manage cluster state only
  {
    name               = "es-master-pool"
    machine_type       = "e2-standard-2"      # 2 vCPU, 8GB RAM
    node_count         = 3                    # 1 master per GKE node for HA
    disk_type          = "pd-ssd"
    disk_size_gb       = 50
    enable_autoscaling = false                # Fixed count — always 3 masters
    labels = {
      "pool-type"       = "elasticsearch"
      "elastic.co/role" = "master"
    }
    tags = ["gke-node", "es-master"]
    taints = [
      {
        key    = "elastic.co/role"
        value  = "master"
        effect = "NO_SCHEDULE"
      }
    ]
  },

  # ── ES DATA POOL ────────────────────────────────────────────────────────
  # Runs: 3 ES data nodes (storage, indexing, search, ingest pipelines)
  # n2-highmem-4: HIGH MEMORY is critical for ES data nodes because:
  #   - JVM heap = 16g (50% of 32GB) → compressed oops, efficient GC
  #   - Remaining 16GB → OS file cache for Lucene segment reads
  #   - This 50/50 split is Elastic's #1 performance recommendation
  # Taints ensure ONLY ES data pods land here
  {
    name               = "es-data-pool"
    machine_type       = "n2-highmem-4"       # 4 vCPU, 32GB RAM
    node_count         = 3
    disk_type          = "pd-ssd"             # SSD mandatory for ES data
    disk_size_gb       = 500                  # Match ES PVC size
    enable_autoscaling = false                # Scale deliberately, not auto
    labels = {
      "pool-type"       = "elasticsearch"
      "elastic.co/role" = "data"
    }
    tags = ["gke-node", "es-data"]
    taints = [
      {
        key    = "elastic.co/role"
        value  = "data"
        effect = "NO_SCHEDULE"
      }
    ]
  }

  # ── FUTURE: ADD MORE POOLS HERE ──────────────────────────────────────
  # Example: dedicated Kibana pool, ML nodes, warm/cold data tiers
  #
  # {
  #   name         = "es-warm-pool"
  #   machine_type = "n2-standard-4"
  #   node_count   = 2
  #   disk_type    = "pd-balanced"         # HDD is fine for warm data
  #   disk_size_gb = 2000
  #   labels       = { "elastic.co/role" = "warm" }
  #   taints       = [{ key = "elastic.co/role", value = "warm", effect = "NO_SCHEDULE" }]
  # }
]

# =============================================================================
# Labels
# =============================================================================
labels = {
  project      = "project-a"
  cluster-name = "proja-cluster-1"
  managed-by   = "terraform"
  workload     = "elastic-stack"
}
