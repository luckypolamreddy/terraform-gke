module "vpc" {
  source = "../../modules/vpc"
  count  = var.enable_vpc ? 1 : 0

  project_id   = var.project_id
  vpc_name     = var.vpc_name
  routing_mode = var.routing_mode
  description  = var.vpc_description
}
