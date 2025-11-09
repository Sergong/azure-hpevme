# Azure UDR for Overlay Network Routing

## Overview

This document explains the critical role of Azure User-Defined Routes (UDR) in this architecture. The UDR provides centralized routing for the VXLAN overlay network (`192.168.10.0/24`), ensuring that all resources in the Azure VNet can communicate with the nested VMs.

## The Problem

Without a UDR, only the gateway KVM host (`vme-kvm-vm1`) would know how to reach the overlay network. Other resources in the VNet, such as the second KVM host (`vme-kvm-vm2`) and the Windows jumphost, would not have a route to the `192.168.10.0/24` network. This would prevent them from communicating with the nested VMs.

## The Solution: Azure User-Defined Route (UDR)

Instead of configuring and maintaining individual routes on each VM, we use a single Azure Route Table that is associated with our subnet. This route table contains a single, powerful rule:

-   **Destination**: `192.168.10.0/24` (the overlay network)
-   **Next Hop**: `VirtualAppliance` at `10.0.1.4` (the IP address of the gateway KVM host)

This tells the Azure networking fabric to forward all packets destined for the overlay network to our gateway host, which then knows how to route them to the nested VMs.

### Terraform Configuration

This is all configured in `main.tf`:

```hcl
# Route Table for overlay network routing
resource "azurerm_route_table" "overlay_routes" {
  name                = "${var.prefix}-overlay-routes"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name                   = "overlay-network-to-gateway"
    address_prefix         = "192.168.10.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.vm_ips[0]  # This is 10.0.1.4
  }
}

# Associate route table with the VM subnet
resource "azurerm_subnet_route_table_association" "vm_subnet_routes" {
  subnet_id      = azurerm_subnet.vm_subnet.id
  route_table_id = azurerm_route_table.overlay_routes.id
}
```

## Benefits

-   **Centralized Management**: A single routing rule for the entire VNet.
-   **Automatic Propagation**: The route is automatically applied to all current and future resources in the subnet.
-   **Simplified Host Configuration**: No need for manual route configuration on the individual VMs.
-   **Full Connectivity**: Enables resources like the Windows jumphost to access the nested VMs.

## Verification

You can verify that the UDR is in effect by checking the effective routes on the network interface of any VM in the subnet (e.g., `vme-kvm-vm2-nic`):

```bash
az network nic show-effective-route-table \
  --resource-group <your-resource-group> \
  --name vme-kvm-vm2-nic \
  --output table
```

You should see a `User` route for `192.168.10.0/24` with a next hop of `10.0.1.4`.