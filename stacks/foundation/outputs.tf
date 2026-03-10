output "vpc_name" {
  value = var.enable_vpc ? module.vpc[0].vpc_name : null
}

output "vpc_self_link" {
  value = var.enable_vpc ? module.vpc[0].vpc_self_link : null
}
