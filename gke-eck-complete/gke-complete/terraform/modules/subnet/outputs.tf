output "name" {
  value = google_compute_subnetwork.this.name
}

output "id" {
  value = google_compute_subnetwork.this.id
}

output "self_link" {
  value = google_compute_subnetwork.this.self_link
}

output "secondary_ranges" {
  description = "Map of secondary range name to CIDR"
  value       = { for r in google_compute_subnetwork.this.secondary_ip_range : r.range_name => r.ip_cidr_range }
}
