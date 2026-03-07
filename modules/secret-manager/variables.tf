variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "secret_ids" {
  description = "List of secret IDs to create"
  type        = list(string)
}

variable "labels" {
  description = "Labels to apply to secrets"
  type        = map(string)
  default     = {}
}

variable "iam_bindings" {
  description = "IAM bindings for secrets"
  type = list(object({
    secret_id = string
    role      = string
    member    = string
  }))
  default = []
}
