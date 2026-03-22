output "hot_bucket_name" {
  description = "Name of the hot snapshot GCS bucket"
  value       = module.hot_snapshot_bucket.bucket_name
}

output "hot_bucket_url" {
  description = "URL of the hot snapshot GCS bucket"
  value       = module.hot_snapshot_bucket.bucket_url
}

output "cold_bucket_name" {
  description = "Name of the cold snapshot GCS bucket"
  value       = module.cold_snapshot_bucket.bucket_name
}

output "cold_bucket_url" {
  description = "URL of the cold snapshot GCS bucket"
  value       = module.cold_snapshot_bucket.bucket_url
}
