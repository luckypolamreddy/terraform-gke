output "cluster_name" {
  value = module.gke_cluster.cluster_name
}

output "cluster_id" {
  value = module.gke_cluster.cluster_id
}

output "cluster_endpoint" {
  value     = module.gke_cluster.cluster_endpoint
  sensitive = true
}

output "cluster_location" {
  value = module.gke_cluster.cluster_location
}

output "subnet_name" {
  value = local.is_default ? "default" : module.subnet[0].subnet_name
}

output "subnet_self_link" {
  value = local.is_default ? "default" : module.subnet[0].subnet_self_link
}

output "network_mode" {
  value = var.network_mode
}

output "subnet_cidr" {
  value = local.is_default ? "auto-allocated" : local.subnet_cidr
}

output "pods_cidr" {
  value = local.is_default ? "auto-allocated" : local.pods_cidr
}

output "services_cidr" {
  value = local.is_default ? "auto-allocated" : local.services_cidr
}

output "snapshot_bucket_name" {
  description = "GCS bucket name for Elasticsearch snapshots"
  value       = module.snapshot_bucket.bucket_name
}

output "snapshot_bucket_url" {
  description = "GCS bucket URL for Elasticsearch snapshots"
  value       = module.snapshot_bucket.bucket_url
}
