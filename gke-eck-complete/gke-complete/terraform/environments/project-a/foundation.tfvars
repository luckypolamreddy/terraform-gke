# =============================================================================
# Project A — Foundation (persistent resources — never destroyed with clusters)
# =============================================================================

project_id = "gcp-project-a-id"    # CHANGE
region     = "us-east1"

# --- VPC ---
vpc_name         = "proja-gke-vpc"
vpc_routing_mode = "REGIONAL"
vpc_description  = "VPC for GKE clusters in project A"

vpc_firewall_rules = [
  {
    name        = "proja-allow-internal"
    description = "Allow all internal traffic"
    allow = [
      { protocol = "tcp" },
      { protocol = "udp" },
      { protocol = "icmp" },
    ]
    ranges = ["10.0.0.0/8"]
  },
  {
    name        = "proja-allow-health-checks"
    description = "Allow GCP health checks for LoadBalancers"
    allow = [
      { protocol = "tcp" },
    ]
    ranges = ["35.191.0.0/16", "130.211.0.0/22", "209.85.152.0/22", "209.85.204.0/22"]
  }
]

# --- GCS Bucket (Elasticsearch snapshots + app configs) ---
gcs_name          = "proja-elastic-snapshots"    # CHANGE: globally unique
gcs_location      = "US-EAST1"
gcs_storage_class = "STANDARD"
gcs_versioning    = true
gcs_force_destroy = false

gcs_lifecycle_rules = [
  {
    action               = "SetStorageClass"
    target_storage_class = "NEARLINE"
    age_days             = 90
  }
]

gcs_iam_bindings = [
  {
    role   = "roles/storage.objectAdmin"
    member = "serviceAccount:gke-sa@gcp-project-a-id.iam.gserviceaccount.com"    # CHANGE
  }
]

# --- Secret Manager ---
secret_ids = [
  "app-database-password",
  "app-api-key",
  "app-tls-cert",
  "elastic-stack-kibana-credentials",    # Kibana login pushed here by ECK sync job
]

secret_iam_bindings = [
  {
    role   = "roles/secretmanager.secretAccessor"
    member = "serviceAccount:gke-sa@gcp-project-a-id.iam.gserviceaccount.com"    # CHANGE
  },
  {
    role   = "roles/secretmanager.secretVersionAdder"
    member = "serviceAccount:gke-sa@gcp-project-a-id.iam.gserviceaccount.com"    # CHANGE
  }
]

# --- Labels ---
labels = {
  project    = "project-a"
  managed-by = "terraform"
}
