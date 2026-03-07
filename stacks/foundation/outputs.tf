output "vpc_name" {
  value = var.enable_vpc ? module.vpc[0].vpc_name : null
}

output "vpc_self_link" {
  value = var.enable_vpc ? module.vpc[0].vpc_self_link : null
}

output "gcs_bucket_name" {
  value = var.enable_gcs ? module.gcs_bucket[0].bucket_name : null
}

output "gcs_bucket_url" {
  value = var.enable_gcs ? module.gcs_bucket[0].bucket_url : null
}

output "secret_ids" {
  value = var.enable_secret_manager ? module.secret_manager[0].secret_ids : []
}
