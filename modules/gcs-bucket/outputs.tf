output "bucket_name" {
  description = "Name of the GCS bucket"
  value       = google_storage_bucket.bucket.name
}

output "bucket_url" {
  description = "URL of the GCS bucket"
  value       = google_storage_bucket.bucket.url
}

output "bucket_self_link" {
  description = "Self link of the GCS bucket"
  value       = google_storage_bucket.bucket.self_link
}
