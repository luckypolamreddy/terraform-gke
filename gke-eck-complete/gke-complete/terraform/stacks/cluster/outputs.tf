output "cluster_name" {
  value = module.gke.name
}

output "cluster_id" {
  value = module.gke.id
}

output "cluster_endpoint" {
  value     = module.gke.endpoint
  sensitive = true
}

output "cluster_location" {
  value = module.gke.location
}

output "cluster_master_version" {
  value = module.gke.master_version
}

output "subnet_name" {
  value = module.subnet.name
}

output "node_pool_names" {
  value = module.gke.node_pool_names
}
