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
      
    }
  ]
}



# Windows Jumphost Outputs
output "jumphost_name" {
  description = "Name of the Windows jumphost"
  value       = azurerm_windows_virtual_machine.jumphost.name
}

output "jumphost_public_ip" {
  description = "Public IP address of the Windows jumphost"
  value       = azurerm_public_ip.jumphost_public_ip.ip_address
}

output "jumphost_private_ip" {
  description = "Private IP address of the Windows jumphost"
  value       = azurerm_network_interface.jumphost_nic.private_ip_address
}

output "jumphost_rdp_command" {
  description = "RDP connection information"
  value       = "mstsc /v:${azurerm_public_ip.jumphost_public_ip.ip_address}"
}

output "jumphost_details" {
  description = "Windows jumphost details"
  value = {
    name               = azurerm_windows_virtual_machine.jumphost.name
    size               = azurerm_windows_virtual_machine.jumphost.size
    private_ip         = azurerm_network_interface.jumphost_nic.private_ip_address
    public_ip          = azurerm_public_ip.jumphost_public_ip.ip_address
    admin_username     = azurerm_windows_virtual_machine.jumphost.admin_username
    rdp_command        = "mstsc /v:${azurerm_public_ip.jumphost_public_ip.ip_address}"
    target_vm_ip       = "10.0.1.20"
    access_instruction = "RDP to this jumphost, then access http://10.0.1.20 from the browser"
  }
}

# Private DNS Zone Outputs
output "private_dns_zone_name" {
  description = "Name of the private DNS zone"
  value       = azurerm_private_dns_zone.main.name
}

output "dns_hostnames" {
  description = "DNS hostnames for all VMs within the VNet"
  value = {
    linux_vms = [
      for i in range(var.vm_count) : {
        hostname        = "${var.prefix}-vm${i + 1}.${azurerm_private_dns_zone.main.name}"
        traffic_hostname = "${var.prefix}-vm${i + 1}-traffic.${azurerm_private_dns_zone.main.name}"
        management_ip   = azurerm_network_interface.management_nic[i].private_ip_address
        traffic_ip      = var.vm_traffic_ips[i]
      }
    ]
    jumphost = {
      hostname    = "jumphost.${azurerm_private_dns_zone.main.name}"
      private_ip  = var.jumphost_ip
    }
    hpevme = {
      hostname    = "hpevme.${azurerm_private_dns_zone.main.name}"
      private_ip  = "10.0.1.20"
      description = "HPE VME nested VM"
    }
  }
}
