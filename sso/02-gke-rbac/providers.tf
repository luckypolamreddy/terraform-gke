terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Update backend configuration per environment
  backend "gcs" {
    # bucket = "your-terraform-state-bucket"
    # prefix = "sso/gke-rbac"
  }
}

provider "google" {
  project = var.project_id
  region  = var.cluster_location
}
