###############################################################################
# VPC Module - Generic
# All configuration via variables. No hardcoded values.
###############################################################################

resource "google_compute_network" "this" {
  name                    = var.name
  project                 = var.project_id
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = var.routing_mode
  description             = var.description
  mtu                     = var.mtu
}

resource "google_compute_firewall" "rules" {
  for_each = { for r in var.firewall_rules : r.name => r }

  name        = each.value.name
  project     = var.project_id
  network     = google_compute_network.this.self_link
  description = each.value.description
  direction   = each.value.direction
  priority    = each.value.priority
  disabled    = each.value.disabled

  dynamic "allow" {
    for_each = each.value.allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  dynamic "deny" {
    for_each = each.value.deny
    content {
      protocol = deny.value.protocol
      ports    = deny.value.ports
    }
  }

  source_ranges      = each.value.direction == "INGRESS" ? each.value.ranges : null
  destination_ranges = each.value.direction == "EGRESS" ? each.value.ranges : null
  target_tags        = each.value.target_tags
  source_tags        = each.value.direction == "INGRESS" ? each.value.source_tags : null
}
