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

variable "nested_vm_ip_ranges" {
  description = "IP ranges for nested VMs per KVM host (CIDR notation). Each host gets a /28 (16 IPs, ~12 usable)"
  type        = list(string)
  default     = [
    "10.0.1.16/28",   # vme-kvm-vm1: IPs .16-.31 (includes .20)
    "10.0.1.48/28",   # vme-kvm-vm2: IPs .48-.63
    "10.0.1.80/28",   # Future host 3: IPs .80-.95
    "10.0.1.96/28",   # Future host 4: IPs .96-.111
    "10.0.1.112/28",  # Future host 5: IPs .112-.127
    "10.0.1.128/28",  # Future host 6: IPs .128-.143
    "10.0.1.144/28",  # Future host 7: IPs .144-.159
    "10.0.1.160/28",  # Future host 8: IPs .160-.175
    "10.0.1.176/28",  # Future host 9: IPs .176-.191
    "10.0.1.192/28"   # Future host 10: IPs .192-.207
  ]
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
