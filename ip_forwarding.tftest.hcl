# Tests for IP forwarding and routing, executed in the root module scope

run "verify_ip_forwarding_enabled_on_kvm_hosts" {
  command = plan

  variables {
    jumphost_admin_password = "Password123!"
  }

  assert {
    condition     = alltrue([for nic in azurerm_network_interface.vm_nic : nic.ip_forwarding_enabled])
    error_message = "IP forwarding must be enabled on all KVM host NICs"
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
    error_message = "Route next_hop_type should be VirtualAppliance"
  }

  assert {
    condition     = anytrue([for r in azurerm_route_table.overlay_routes.route : r.next_hop_in_ip_address == var.vm_ips[0]])
    error_message = "Route next hop IP should be the gateway host IP (vm_ips[0])"
  }
}
