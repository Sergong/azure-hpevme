# Static IP Assignment Verification

## Overview
This document explains how to verify that the KVM host VMs receive their static IP assignments correctly. This is **critical** for the overlay network architecture to function, as the Azure UDR depends on Host 1 having IP `10.0.1.4`.

## Why Static IPs Are Required

The architecture depends on predictable IP assignments:

1. **Azure UDR** routes overlay traffic (192.168.10.0/24) to `10.0.1.4`
2. **Host 1** (vme-kvm-vm1) MUST have IP `10.0.1.4` (gateway host)
3. **Host 2** (vme-kvm-vm2) MUST have IP `10.0.1.5`
4. **Jumphost** MUST have IP `10.0.1.200`

If these IPs change, the overlay network routing will break.

## Current Configuration

### Terraform Variables (`variables.tf`)

```hcl
variable "vm_ips" {
  description = "Static IP addresses for KVM host VMs (must be within 10.0.1.0/24). IMPORTANT: First IP (vm_ips[0]) MUST be 10.0.1.4 as it's used in Azure UDR for overlay network routing."
  type        = list(string)
  default     = ["10.0.1.4", "10.0.1.5"]
  
  validation {
    condition     = var.vm_ips[0] == "10.0.1.4"
    error_message = "First VM IP (vm_ips[0]) must be 10.0.1.4 for Azure UDR overlay network routing."
  }
}
```

**Protection:** Terraform will **fail validation** if you try to change `vm_ips[0]` to anything other than `10.0.1.4`.

### NIC Configuration (`main.tf`)

```hcl
resource "azurerm_network_interface" "vm_nic" {
  count = var.vm_count
  
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Static"  # ✅ Static allocation
    private_ip_address            = var.vm_ips[count.index]  # ✅ Explicit IP assignment
    public_ip_address_id          = azurerm_public_ip.vm_public_ip[count.index].id
  }
}
```

**Guarantees:**
- ✅ `private_ip_address_allocation = "Static"` ensures IPs won't change
- ✅ `private_ip_address = var.vm_ips[count.index]` assigns specific IPs
- ✅ count.index = 0 gets `vm_ips[0]` = `10.0.1.4`
- ✅ count.index = 1 gets `vm_ips[1]` = `10.0.1.5`

### Route Table Configuration (`main.tf`)

```hcl
resource "azurerm_route_table" "overlay_routes" {
  route {
    name                   = "overlay-network-to-gateway"
    address_prefix         = "192.168.10.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.vm_ips[0]  # ✅ References same variable
  }
}
```

**Consistency:** Route table uses `var.vm_ips[0]` directly, ensuring it always matches the first VM's IP.

## Verification Steps

### 1. Before Terraform Apply

Run `terraform plan` and verify the output shows static IPs:

```bash
terraform plan
```

Look for the NIC configuration in the plan output:

```
# azurerm_network_interface.vm_nic[0] will be created
  + resource "azurerm_network_interface" "vm_nic" {
      + name                 = "vme-kvm-vm1-nic"
      + ip_configuration {
          + name                          = "primary"
          + private_ip_address            = "10.0.1.4"  # ✅ Should show 10.0.1.4
          + private_ip_address_allocation = "Static"    # ✅ Should say "Static"
        }
    }

# azurerm_network_interface.vm_nic[1] will be created
  + resource "azurerm_network_interface" "vm_nic" {
      + name                 = "vme-kvm-vm2-nic"
      + ip_configuration {
          + name                          = "primary"
          + private_ip_address            = "10.0.1.5"  # ✅ Should show 10.0.1.5
          + private_ip_address_allocation = "Static"    # ✅ Should say "Static"
        }
    }
```

**What to check:**
- ✅ `private_ip_address_allocation = "Static"` (not "Dynamic")
- ✅ `private_ip_address = "10.0.1.4"` for vm1
- ✅ `private_ip_address = "10.0.1.5"` for vm2

### 2. After Terraform Apply

#### Check Terraform State

```bash
# View VM NIC details
terraform state show 'azurerm_network_interface.vm_nic[0]'
terraform state show 'azurerm_network_interface.vm_nic[1]'
```

Expected output for vm_nic[0]:
```
resource "azurerm_network_interface" "vm_nic" {
    id                            = "/subscriptions/.../networkInterfaces/vme-kvm-vm1-nic"
    name                          = "vme-kvm-vm1-nic"
    private_ip_address            = "10.0.1.4"
    private_ip_address_allocation = "Static"
    # ...
}
```

#### Check Terraform Outputs

```bash
terraform output vm_private_ip_addresses
```

Expected:
```
[
  "10.0.1.4",
  "10.0.1.5",
]
```

#### Verify via Azure CLI

```bash
# Check NIC details for Host 1
az network nic show \
  --resource-group rg-hpe-vme-test \
  --name vme-kvm-vm1-nic \
  --query "ipConfigurations[0].{Name:name,PrivateIP:privateIPAddress,Allocation:privateIPAllocationMethod}" \
  --output table

# Expected output:
# Name     PrivateIP    Allocation
# -------  -----------  ------------
# primary  10.0.1.4     Static

# Check NIC details for Host 2
az network nic show \
  --resource-group rg-hpe-vme-test \
  --name vme-kvm-vm2-nic \
  --query "ipConfigurations[0].{Name:name,PrivateIP:privateIPAddress,Allocation:privateIPAllocationMethod}" \
  --output table

# Expected output:
# Name     PrivateIP    Allocation
# -------  -----------  ------------
# primary  10.0.1.5     Static
```

#### Verify Route Table Matches

```bash
# Check route table configuration
az network route-table route show \
  --resource-group rg-hpe-vme-test \
  --route-table-name vme-kvm-overlay-routes \
  --name overlay-network-to-gateway \
  --query "{AddressPrefix:addressPrefix,NextHopType:nextHopType,NextHopIP:nextHopIpAddress}" \
  --output table

# Expected output:
# AddressPrefix     NextHopType        NextHopIP
# ----------------  -----------------  -----------
# 192.168.10.0/24   VirtualAppliance   10.0.1.4
```

### 3. From Inside the VMs

#### SSH to Host 1

```bash
ssh adm_smeeuwsen@<HOST1_PUBLIC_IP>

# Check IP address
ip addr show eth0

# Expected output should include:
# inet 10.0.1.4/24 brd 10.0.1.255 scope global eth0
```

#### SSH to Host 2

```bash
ssh adm_smeeuwsen@<HOST2_PUBLIC_IP>

# Check IP address
ip addr show eth0

# Expected output should include:
# inet 10.0.1.5/24 brd 10.0.1.255 scope global eth0
```

## Troubleshooting

### Problem: Terraform plan shows "known after apply"

**Cause:** This is normal for certain computed attributes (like NIC ID), but the IP address itself should be shown.

**Solution:** Look specifically at the `private_ip_address` field in the plan output. It should show the actual IP, not "(known after apply)".

### Problem: Wrong IP assigned after apply

**Symptom:** VM gets different IP than expected (e.g., 10.0.1.5 instead of 10.0.1.4)

**Diagnosis:**
```bash
# Check what IPs were requested
terraform state show 'azurerm_network_interface.vm_nic[0]' | grep private_ip
```

**Possible causes:**
1. ❌ Variable override in terraform.tfvars
2. ❌ Subnet IP conflict (another resource using the IP)
3. ❌ Azure rejected the static IP request

**Solution:**
```bash
# Check terraform.tfvars doesn't override vm_ips
grep vm_ips terraform.tfvars

# Verify no IP conflicts
az network nic list \
  --resource-group rg-hpe-vme-test \
  --query "[].{Name:name,PrivateIP:ipConfigurations[0].privateIPAddress}" \
  --output table

# If wrong IP assigned, destroy and recreate
terraform destroy -target=azurerm_network_interface.vm_nic[0]
terraform apply
```

### Problem: Overlay routing not working

**Diagnosis:**
```bash
# Check if route table has correct next hop
az network route-table route show \
  --resource-group rg-hpe-vme-test \
  --route-table-name vme-kvm-overlay-routes \
  --name overlay-network-to-gateway

# Check effective routes on a NIC
az network nic show-effective-route-table \
  --resource-group rg-hpe-vme-test \
  --name vme-kvm-vm2-nic \
  --output table | grep 192.168.10.0
```

**Solution:** If route table next hop doesn't match Host 1 IP:
```bash
# Update route table (this should not be needed if Terraform is configured correctly)
az network route-table route update \
  --resource-group rg-hpe-vme-test \
  --route-table-name vme-kvm-overlay-routes \
  --name overlay-network-to-gateway \
  --next-hop-ip-address 10.0.1.4
```

## Best Practices

### 1. Never Change vm_ips[0]

The first IP in the `vm_ips` variable is protected by validation:

```hcl
validation {
  condition     = var.vm_ips[0] == "10.0.1.4"
  error_message = "First VM IP must be 10.0.1.4 for Azure UDR."
}
```

If you need to change it, you must:
1. Update the validation rule
2. Update the Azure UDR
3. Update Ansible inventory gateway_host configuration
4. Potentially recreate all infrastructure

### 2. Don't Override in terraform.tfvars

Avoid overriding `vm_ips` in `terraform.tfvars` unless you have a specific reason and understand the implications.

### 3. Use Terraform State as Source of Truth

After deployment, verify IPs using:
```bash
terraform state show 'azurerm_network_interface.vm_nic[0]'
```

Not Azure Portal, as Terraform state is the authoritative source.

### 4. Document Changes

If you ever need to change the IP scheme:
1. Update variables.tf (including validation)
2. Update main.tf (route table)
3. Update inventory.yml (Ansible)
4. Update documentation (README, NESTED-VM-NETWORKING, etc.)
5. Plan and apply carefully

## Summary

The static IP configuration is **correctly implemented** and **validated** at multiple levels:

✅ **Terraform Variables** - Default values and validation  
✅ **NIC Configuration** - Static allocation with explicit IPs  
✅ **Route Table** - References same variable  
✅ **Verification Steps** - Multiple ways to confirm  
✅ **Protection** - Validation prevents accidental changes  

As long as you don't override the `vm_ips` variable, the static IPs will be assigned correctly and consistently.

---
**Last Updated:** 2025-11-03  
**Critical IPs:** vme-kvm-vm1=10.0.1.4 (gateway), vme-kvm-vm2=10.0.1.5
