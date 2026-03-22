# GKE IAM Bindings for Team Members
# Maps @gcp.pwc.com users to GKE cluster roles via Google Cloud IAM.
#
# This provides cluster-level access control:
#   - Admins: Full cluster admin (container.admin)
#   - Editors: Deploy and manage workloads (container.developer)
#   - Viewers: Read-only access (container.viewer)

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
}

variable "cluster_location" {
  description = "GKE cluster location (region or zone)"
  type        = string
}

# -------------------------------------------------------
# Team members grouped by role
# Update these lists when team members join/leave
# -------------------------------------------------------

variable "admin_members" {
  description = "List of @gcp.pwc.com emails with admin access"
  type        = list(string)
  default = [
    "teamlead1@gcp.pwc.com",
    "teamlead2@gcp.pwc.com",
    "devops1@gcp.pwc.com",
    "devops2@gcp.pwc.com",
  ]
}

variable "editor_members" {
  description = "List of @gcp.pwc.com emails with editor access"
  type        = list(string)
  default = [
    "developer1@gcp.pwc.com",
    "developer2@gcp.pwc.com",
    "developer3@gcp.pwc.com",
    "developer4@gcp.pwc.com",
    "developer5@gcp.pwc.com",
    "developer6@gcp.pwc.com",
    "developer7@gcp.pwc.com",
    "developer8@gcp.pwc.com",
    "developer9@gcp.pwc.com",
    "developer10@gcp.pwc.com",
  ]
}

variable "viewer_members" {
  description = "List of @gcp.pwc.com emails with viewer access"
  type        = list(string)
  default = [
    "qa1@gcp.pwc.com",
    "qa2@gcp.pwc.com",
    "qa3@gcp.pwc.com",
    "analyst1@gcp.pwc.com",
    "analyst2@gcp.pwc.com",
    "manager1@gcp.pwc.com",
  ]
}

# -------------------------------------------------------
# GKE Cluster IAM Bindings
# -------------------------------------------------------

# Admin role - full cluster management
resource "google_project_iam_member" "gke_admin" {
  for_each = toset(var.admin_members)

  project = var.project_id
  role    = "roles/container.admin"
  member  = "user:${each.value}"
}

# Editor role - deploy and manage workloads
resource "google_project_iam_member" "gke_developer" {
  for_each = toset(var.editor_members)

  project = var.project_id
  role    = "roles/container.developer"
  member  = "user:${each.value}"
}

# Viewer role - read-only access
resource "google_project_iam_member" "gke_viewer" {
  for_each = toset(var.viewer_members)

  project = var.project_id
  role    = "roles/container.viewer"
  member  = "user:${each.value}"
}

# All members need basic cluster access to run kubectl
resource "google_project_iam_member" "gke_cluster_viewer" {
  for_each = toset(concat(var.admin_members, var.editor_members, var.viewer_members))

  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = "user:${each.value}"
}

# -------------------------------------------------------
# Outputs
# -------------------------------------------------------

output "admin_users" {
  description = "Users with admin access"
  value       = var.admin_members
}

output "editor_users" {
  description = "Users with editor access"
  value       = var.editor_members
}

output "viewer_users" {
  description = "Users with viewer access"
  value       = var.viewer_members
}

output "total_users" {
  description = "Total number of users with GKE access"
  value       = length(var.admin_members) + length(var.editor_members) + length(var.viewer_members)
}
