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

variable "vm_traffic_ips" {
  description = "Static IP addresses for VM traffic subnet (must be within 10.0.1.0/24)"
  type        = list(string)
  default     = ["10.0.1.10", "10.0.1.11", "10.0.1.12", "10.0.1.13", "10.0.1.14", "10.0.1.15", "10.0.1.16", "10.0.1.17", "10.0.1.18", "10.0.1.19"]
  validation {
    condition     = length(var.vm_traffic_ips) >= 1 && length(var.vm_traffic_ips) <= 10
    error_message = "Must provide between 1 and 10 IP addresses."
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
  description = "Static IP address for Windows jumphost in management subnet (10.0.2.0/24)"
  type        = string
  default     = "10.0.2.100"
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
