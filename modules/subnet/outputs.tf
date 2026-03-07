output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_self_link" {
  description = "Self link of the subnet"
  value       = google_compute_subnetwork.subnet.self_link
}
