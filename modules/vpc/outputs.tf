output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.vpc.name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = google_compute_network.vpc.id
}

output "vpc_self_link" {
  description = "Self link of the VPC"
  value       = google_compute_network.vpc.self_link
}
