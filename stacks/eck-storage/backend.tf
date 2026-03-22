terraform {
  backend "gcs" {
    # Configure via -backend-config during terraform init:
    #   terraform init \
    #     -backend-config="bucket=<tf-state-bucket>" \
    #     -backend-config="prefix=eck-storage/<project>/<cluster-name>"
  }
}
