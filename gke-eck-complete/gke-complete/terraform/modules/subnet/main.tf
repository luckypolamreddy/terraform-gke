###############################################################################
# Subnet Module - Generic
# Secondary ranges, flow logs, private google access all via variables.
###############################################################################

resource "google_compute_subnetwork" "this" {
  name                     = var.name
  project                  = var.project_id
  region                   = var.region
  network                  = var.network_self_link
  ip_cidr_range            = var.ip_cidr_range
  private_ip_google_access = var.private_ip_google_access
  description              = var.description
  purpose                  = var.purpose
  stack_type               = var.stack_type

  dynamic "secondary_ip_range" {
    for_each = var.secondary_ranges
    content {
      range_name    = secondary_ip_range.value.name
      ip_cidr_range = secondary_ip_range.value.cidr
    }
  }

  dynamic "log_config" {
    for_each = var.enable_flow_logs ? [1] : []
    content {
      aggregation_interval = var.flow_logs_interval
      flow_sampling        = var.flow_logs_sampling
      metadata             = var.flow_logs_metadata
      filter_expr          = var.flow_logs_filter
    }
  }
}
