terraform {
  backend "gcs" {
    # Configure via -backend-config during terraform init:
    #   terraform init \
    #     -backend-config="bucket=<tf-state-bucket>" \
    #     -backend-config="prefix=backup/<backup-plan-name>"
  }
}
