# Unit tests for Azure Route Tables configuration
# Test Case 1: Verify that Azure Route Tables are correctly configured to direct nested VM traffic to the appropriate KVM host

run "verify_route_table_creation" {
  command = plan

  assert {
    condition     = azurerm_route_table.nested_vm_routes.name == "ubuntu-nested-vm-routes"
    error_message = "Route table name is incorrect"
  }

  assert {
    condition     = azurerm_route_table.nested_vm_routes.location == var.location
    error_message = "Route table location does not match var.location"
  }
}

run "verify_route_count_matches_vm_count" {
  command = plan

  assert {
    condition     = length(azurerm_route.nested_vm_route) == var.vm_count
    error_message = "Number of routes should match vm_count"
  }
}

run "verify_route_configuration_vm1" {
  command = plan

  variables {
    vm_count = 2
    vm_traffic_ips = ["10.0.1.10", "10.0.1.11"]
    nested_vm_ip_ranges = ["10.0.1.16/28", "10.0.1.48/28"]
  }

  assert {
    condition     = azurerm_route.nested_vm_route[0].address_prefix == "10.0.1.16/28"
    error_message = "First route address prefix should be 10.0.1.16/28"
  }

  assert {
    condition     = azurerm_route.nested_vm_route[0].next_hop_type == "VirtualAppliance"
    error_message = "Route next_hop_type should be VirtualAppliance"
  }

  assert {
    condition     = azurerm_route.nested_vm_route[0].next_hop_in_ip_address == "10.0.1.10"
    error_message = "First route should point to first KVM host IP (10.0.1.10)"
  }
}

run "verify_route_configuration_vm2" {
  command = plan

  variables {
    vm_count = 2
    vm_traffic_ips = ["10.0.1.10", "10.0.1.11"]
    nested_vm_ip_ranges = ["10.0.1.16/28", "10.0.1.48/28"]
  }

  assert {
    condition     = azurerm_route.nested_vm_route[1].address_prefix == "10.0.1.48/28"
    error_message = "Second route address prefix should be 10.0.1.48/28"
  }

  assert {
    condition     = azurerm_route.nested_vm_route[1].next_hop_in_ip_address == "10.0.1.11"
    error_message = "Second route should point to second KVM host IP (10.0.1.11)"
  }
}

run "verify_route_table_subnet_association" {
  command = plan

  assert {
    condition     = azurerm_subnet_route_table_association.vm_subnet_routes.subnet_id == azurerm_subnet.vm_subnet.id
    error_message = "Route table should be associated with VM subnet"
  }

  assert {
    condition     = azurerm_subnet_route_table_association.vm_subnet_routes.route_table_id == azurerm_route_table.nested_vm_routes.id
    error_message = "Subnet association should reference the correct route table"
  }
}

run "verify_routes_for_multiple_hosts" {
  command = plan

  variables {
    vm_count = 4
    vm_traffic_ips = ["10.0.1.10", "10.0.1.11", "10.0.1.12", "10.0.1.13"]
    nested_vm_ip_ranges = ["10.0.1.16/28", "10.0.1.48/28", "10.0.1.80/28", "10.0.1.96/28"]
  }

  assert {
    condition     = length(azurerm_route.nested_vm_route) == 4
    error_message = "Should create 4 routes for 4 VMs"
  }

  assert {
    condition     = azurerm_route.nested_vm_route[2].address_prefix == "10.0.1.80/28"
    error_message = "Third route should have correct address prefix"
  }

  assert {
    condition     = azurerm_route.nested_vm_route[3].next_hop_in_ip_address == "10.0.1.13"
    error_message = "Fourth route should point to fourth KVM host"
  }
}
