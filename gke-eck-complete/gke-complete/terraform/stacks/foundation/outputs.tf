output "vpc_name" {
  value = module.vpc.name
}

output "vpc_self_link" {
  value = module.vpc.self_link
}

output "gcs_bucket_name" {
  value = module.gcs_bucket.name
}

output "gcs_bucket_url" {
  value = module.gcs_bucket.url
}

output "secret_ids" {
  value = module.secret_manager.secret_ids
}
