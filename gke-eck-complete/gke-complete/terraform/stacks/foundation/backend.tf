# Remote state in GCS.
# The state bucket must exist BEFORE running terraform init.
# Create it manually: gsutil mb -p <PROJECT_ID> -l <REGION> gs://<BUCKET>/
terraform {
  backend "gcs" {
    # Set via -backend-config in the pipeline:
    #   bucket = "<project-id>-tf-state"
    #   prefix = "foundation"
  }
}
