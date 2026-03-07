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
  value = module.subnet.subnet_name
}

output "subnet_self_link" {
  value = module.subnet.subnet_self_link
}
