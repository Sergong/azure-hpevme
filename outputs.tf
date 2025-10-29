output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vm_names" {
  description = "Names of the created VMs"
  value       = azurerm_linux_virtual_machine.vm[*].name
}

output "vm_private_ip_addresses" {
  description = "Private IP addresses of the VMs (VM traffic subnet)"
  value       = azurerm_network_interface.vm_nic[*].private_ip_address
}

output "management_private_ip_addresses" {
  description = "Private IP addresses of the VMs (Management subnet)"
  value       = azurerm_network_interface.management_nic[*].private_ip_address
}

output "vm_public_ip_addresses" {
  description = "Public IP addresses of the VMs"
  value       = azurerm_public_ip.vm_public_ip[*].ip_address
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to the VMs"
  value = [
    for i, vm in azurerm_linux_virtual_machine.vm :
    "ssh ${vm.admin_username}@${azurerm_public_ip.vm_public_ip[i].ip_address}"
  ]
}

output "data_disk_names" {
  description = "Names of the data disks"
  value       = azurerm_managed_disk.data_disk[*].name
}

output "vm_details" {
  description = "Detailed information about each VM"
  value = [
    for i, vm in azurerm_linux_virtual_machine.vm : {
      name                = vm.name
      size                = vm.size
      os_disk_type        = vm.os_disk[0].storage_account_type
      data_disk_name      = azurerm_managed_disk.data_disk[i].name
      data_disk_size      = "${azurerm_managed_disk.data_disk[i].disk_size_gb}GB"
      data_disk_type      = azurerm_managed_disk.data_disk[i].storage_account_type
      vm_traffic_ip       = azurerm_network_interface.vm_nic[i].private_ip_address
      management_ip       = azurerm_network_interface.management_nic[i].private_ip_address
      public_ip           = azurerm_public_ip.vm_public_ip[i].ip_address
      ssh_command         = "ssh ${vm.admin_username}@${azurerm_public_ip.vm_public_ip[i].ip_address}"
      data_mount_path     = "/data"
      nested_vm_ip_range  = var.nested_vm_ip_ranges[i]
    }
  ]
}

output "nested_vm_ip_allocation" {
  description = "IP ranges allocated for nested VMs on each KVM host"
  value = {
    for i in range(var.vm_count) :
    "${var.prefix}-vm${i + 1}" => {
      host_ip            = var.vm_traffic_ips[i]
      nested_vm_range    = var.nested_vm_ip_ranges[i]
      usable_ips         = "Use IPs from this /28 range for nested VMs on this host"
    }
  }
}
