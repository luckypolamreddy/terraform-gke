terraform {
  backend "gcs" {
    # Set via -backend-config in pipeline:
    #   bucket = "<project-id>-tf-state"
    #   prefix = "clusters/<cluster-name>"
  }
}
