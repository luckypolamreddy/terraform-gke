output "vpc_name" {
  value = module.vpc.vpc_name
}

output "vpc_self_link" {
  value = module.vpc.vpc_self_link
}

output "gcs_bucket_name" {
  value = module.gcs_bucket.bucket_name
}

output "gcs_bucket_url" {
  value = module.gcs_bucket.bucket_url
}

output "secret_ids" {
  value = module.secret_manager.secret_ids
}
