# Tests for Azure Route Table configuration for the overlay network, executed in the root module scope

run "verify_route_table_exists" {
  command = plan

  variables {
    jumphost_admin_password = "Password123!"
  }

  assert {
    condition     = azurerm_route_table.overlay_routes.name == "${var.prefix}-overlay-routes"
    error_message = "Route table name should be '<prefix>-overlay-routes'"
  }

  assert {
    condition     = azurerm_route_table.overlay_routes.location == lower(replace(var.location, " ", ""))
    error_message = "Route table location should match var.location (normalized)"
  }
}

run "verify_udr_for_overlay_network" {
  command = plan

  variables {
    jumphost_admin_password = "Password123!"
  }

  assert {
    condition     = anytrue([for r in azurerm_route_table.overlay_routes.route : r.address_prefix == "192.168.10.0/24"]) 
    error_message = "Route address prefix should be 192.168.10.0/24"
  }

  assert {
    condition     = anytrue([for r in azurerm_route_table.overlay_routes.route : r.next_hop_type == "VirtualAppliance"]) 
    error_message = "Route next_hop_type should be 'VirtualAppliance'"
  }

  assert {
    condition     = anytrue([for r in azurerm_route_table.overlay_routes.route : r.next_hop_in_ip_address == var.vm_ips[0]])
    error_message = "Route next hop IP address should be the private IP of the gateway KVM host (vm_ips[0])"
  }
}
