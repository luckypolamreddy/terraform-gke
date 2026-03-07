# =============================================================================
# Project B — Foundation
# =============================================================================

project_id = "gcp-project-b-id"    # CHANGE
region     = "us-east1"

vpc_name         = "projb-gke-vpc"
vpc_routing_mode = "REGIONAL"
vpc_description  = "VPC for GKE clusters in project B"

vpc_firewall_rules = [
  {
    name  = "projb-allow-internal"
    allow = [{ protocol = "tcp" }, { protocol = "udp" }, { protocol = "icmp" }]
    ranges = ["10.0.0.0/8"]
  },
  {
    name  = "projb-allow-health-checks"
    allow = [{ protocol = "tcp" }]
    ranges = ["35.191.0.0/16", "130.211.0.0/22", "209.85.152.0/22", "209.85.204.0/22"]
  }
]

gcs_name     = "projb-elastic-snapshots"    # CHANGE: globally unique
gcs_location = "US-EAST1"

gcs_iam_bindings = [
  {
    role   = "roles/storage.objectAdmin"
    member = "serviceAccount:gke-sa@gcp-project-b-id.iam.gserviceaccount.com"    # CHANGE
  }
]

secret_ids = [
  "app-database-password",
  "app-api-key",
  "app-tls-cert",
  "elastic-stack-kibana-credentials",
]

secret_iam_bindings = [
  {
    role   = "roles/secretmanager.secretAccessor"
    member = "serviceAccount:gke-sa@gcp-project-b-id.iam.gserviceaccount.com"    # CHANGE
  },
  {
    role   = "roles/secretmanager.secretVersionAdder"
    member = "serviceAccount:gke-sa@gcp-project-b-id.iam.gserviceaccount.com"    # CHANGE
  }
]

labels = {
  project    = "project-b"
  managed-by = "terraform"
}
