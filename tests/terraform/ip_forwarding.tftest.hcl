# Unit tests for IP forwarding configuration
# Test Case 2: Verify that ip_forwarding is enabled on the KVM host network interfaces

run "verify_vm_nic_ip_forwarding_enabled" {
  command = plan

  variables {
    vm_count = 2
  }

  assert {
    condition     = azurerm_network_interface.vm_nic[0].enable_ip_forwarding == true
    error_message = "IP forwarding should be enabled on first VM NIC"
  }

  assert {
    condition     = azurerm_network_interface.vm_nic[1].enable_ip_forwarding == true
    error_message = "IP forwarding should be enabled on second VM NIC"
  }
}

run "verify_management_nic_ip_forwarding_enabled" {
  command = plan

  variables {
    vm_count = 2
  }

  assert {
    condition     = azurerm_network_interface.management_nic[0].enable_ip_forwarding == true
    error_message = "IP forwarding should be enabled on first management NIC"
  }

  assert {
    condition     = azurerm_network_interface.management_nic[1].enable_ip_forwarding == true
    error_message = "IP forwarding should be enabled on second management NIC"
  }
}

run "verify_all_nics_have_ip_forwarding" {
  command = plan

  variables {
    vm_count = 4
  }

  assert {
    condition = alltrue([
      for nic in azurerm_network_interface.vm_nic : nic.enable_ip_forwarding == true
    ])
    error_message = "All VM NICs should have IP forwarding enabled"
  }

  assert {
    condition = alltrue([
      for nic in azurerm_network_interface.management_nic : nic.enable_ip_forwarding == true
    ])
    error_message = "All management NICs should have IP forwarding enabled"
  }
}

run "verify_vm_nic_configuration" {
  command = plan

  variables {
    vm_count = 1
    vm_traffic_ips = ["10.0.1.10"]
  }

  assert {
    condition     = azurerm_network_interface.vm_nic[0].ip_configuration[0].name == "vm-traffic"
    error_message = "VM NIC IP configuration name should be 'vm-traffic'"
  }

  assert {
    condition     = azurerm_network_interface.vm_nic[0].ip_configuration[0].private_ip_address_allocation == "Static"
    error_message = "VM NIC should use static IP allocation"
  }

  assert {
    condition     = azurerm_network_interface.vm_nic[0].ip_configuration[0].private_ip_address == "10.0.1.10"
    error_message = "VM NIC should have correct static IP address"
  }
}

run "verify_ip_forwarding_for_all_vm_counts" {
  command = plan

  variables {
    vm_count = 10
  }

  assert {
    condition     = length(azurerm_network_interface.vm_nic) == 10
    error_message = "Should create 10 VM NICs"
  }

  assert {
    condition = alltrue([
      for i in range(10) : azurerm_network_interface.vm_nic[i].enable_ip_forwarding == true
    ])
    error_message = "IP forwarding should be enabled on all 10 VM NICs"
  }

  assert {
    condition = alltrue([
      for i in range(10) : azurerm_network_interface.management_nic[i].enable_ip_forwarding == true
    ])
    error_message = "IP forwarding should be enabled on all 10 management NICs"
  }
}
