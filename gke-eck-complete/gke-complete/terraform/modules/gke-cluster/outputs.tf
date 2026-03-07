output "name" {
  value = google_container_cluster.this.name
}

output "id" {
  value = google_container_cluster.this.id
}

output "endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}

output "ca_certificate" {
  value     = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "location" {
  value = google_container_cluster.this.location
}

output "master_version" {
  value = google_container_cluster.this.master_version
}

output "node_pool_names" {
  value = [for np in google_container_node_pool.pools : np.name]
}

output "usage_metering_dataset_id" {
  value = var.enable_usage_metering ? google_bigquery_dataset.usage_metering[0].dataset_id : ""
}
