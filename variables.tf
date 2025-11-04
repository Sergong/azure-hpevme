variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-ubuntu-vms"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "East US"
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "ubuntu"
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 2
  validation {
    condition     = var.vm_count >= 1 && var.vm_count <= 10
    error_message = "VM count must be between 1 and 10."
  }
}

variable "vm_ips" {
  description = "Static IP addresses for KVM host VMs (must be within 10.0.1.0/24). IMPORTANT: First IP (vm_ips[0]) MUST be 10.0.1.4 as it's used in Azure UDR for overlay network routing."
  type        = list(string)
  default     = ["10.0.1.4", "10.0.1.5"]
  validation {
    condition     = length(var.vm_ips) >= 1 && length(var.vm_ips) <= 10
    error_message = "Must provide between 1 and 10 IP addresses."
  }
  validation {
    condition     = length(var.vm_ips) >= 1 && var.vm_ips[0] == "10.0.1.4"
    error_message = "First VM IP (vm_ips[0]) must be 10.0.1.4 for Azure UDR overlay network routing."
  }
}



variable "vm_size" {
  description = "Size of the Virtual Machine (supports nested virtualization)"
  type        = string
  default     = "Standard_E4as_v5"
}

variable "admin_username" {
  description = "Admin username for the VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "Ubuntu-VMs"
    CreatedBy   = "Terraform"
  }
}

# Windows Jumphost Variables
variable "jumphost_ip" {
  description = "Static IP address for Windows jumphost in VM subnet (10.0.1.0/24)"
  type        = string
  default     = "10.0.1.200"
}

variable "jumphost_vm_size" {
  description = "Size of the Windows jumphost VM"
  type        = string
  default     = "Standard_B2s"
}

variable "jumphost_admin_username" {
  description = "Admin username for Windows jumphost"
  type        = string
  default     = "azureadmin"
}

variable "jumphost_admin_password" {
  description = "Admin password for Windows jumphost (must meet Azure complexity requirements: 12+ chars with upper, lower, number, and special character)"
  type        = string
  sensitive   = true
  # No default - Terraform will prompt for this value
}

variable "my_public_ip" {
  description = "Your public IP address for NSG whitelist (format: x.x.x.x/32)"
  type        = string
  default     = "193.237.155.169/32"
}

variable "private_dns_zone_name" {
  description = "Name of the private DNS zone for internal name resolution"
  type        = string
  default     = "hpevme.local"
}

# Optional tag to force re-run of the jumphost OpenSSH VM extension
variable "openssh_extension_update_tag" {
  description = "Change this value to force the Custom Script Extension to re-run on the Windows jumphost"
  type        = string
  default     = null
}
