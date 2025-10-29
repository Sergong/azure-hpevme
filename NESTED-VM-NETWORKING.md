# Nested VM Networking on Azure KVM Hosts

## Overview

This document describes how nested VMs running on KVM hosts in Azure can communicate across hosts using Azure Route Tables. This solution allows nested VMs to use IPs from the same subnet as the KVM hosts (10.0.1.0/24) without NAT.

## The Problem

Azure enforces source IP validation on NICs. When a nested VM sends traffic with its own IP address, Azure needs to know which KVM host "owns" that IP range. Without this information, Azure drops the packets.

## The Solution: Azure Route Tables + Host Routes

We use a two-part approach:

### Part 1: Azure Route Tables

Terraform creates Azure User-Defined Routes (UDRs) that tell Azure which KVM host owns which IP range:

```hcl
# In main.tf
resource "azurerm_route" "nested_vm_route" {
  count                  = var.vm_count
  address_prefix         = var.nested_vm_ip_ranges[count.index]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.vm_traffic_ips[count.index]
}
```

**IP Allocation:**
- vme-kvm-vm1 (10.0.1.10): Nested VMs use 10.0.1.16-31 (/28)
- vme-kvm-vm2 (10.0.1.11): Nested VMs use 10.0.1.48-63 (/28)
- Future hosts get their own /28 ranges

### Part 2: KVM Host Routes

Each KVM host needs to know how to reach OTHER hosts' nested VM ranges.

Run `setup-nested-vm-routes.sh` on each KVM host to configure:

```bash
# On vme-kvm-vm1
ip route add 10.0.1.48/28 via 10.0.1.11 dev mgmt

# On vme-kvm-vm2  
ip route add 10.0.1.16/28 via 10.0.1.10 dev mgmt
```

The script makes these routes persistent via systemd network configuration.

## Implementation

### Initial Setup (Already Done)

1. **Deploy infrastructure:**
   ```bash
   terraform apply
   ```

2. **Configure KVM host routes:**
   ```bash
   ansible all -m copy -a 'src=setup-nested-vm-routes.sh dest=/tmp/setup-nested-vm-routes.sh mode=0755'
   ansible all -m shell -a 'sudo /tmp/setup-nested-vm-routes.sh'
   ```

3. **Configure UFW (Ubuntu 24.04 firewall):**
   ```bash
   ansible all -m shell -a 'sudo ufw default allow routed'
   ansible all -m shell -a 'sudo ufw allow in on eth0 to any port 22'
   ansible all -m shell -a 'sudo ufw reload'
   ```

### Creating Nested VMs

When creating nested VMs, assign IPs from the appropriate range:

**On vme-kvm-vm1:** Use IPs from 10.0.1.16-31  
**On vme-kvm-vm2:** Use IPs from 10.0.1.48-63

Example nested VM network configuration:

```bash
# Inside nested VM
ip addr add 10.0.1.20/24 dev eth0
ip route add default via 10.0.1.10  # Gateway is the KVM host
```

## Verification

### Check Azure Routes

```bash
az network route-table route list \
  --resource-group rg-hpe-vme-test \
  --route-table-name vme-kvm-nested-vm-routes \
  --output table
```

### Check KVM Host Routes

```bash
ansible all -m shell -a 'ip route show | grep -E "10.0.1.(16|48)/28"'
```

You should see:
- **vme-kvm-vm1**: Route for 10.0.1.48/28 via 10.0.1.11
- **vme-kvm-vm2**: Route for 10.0.1.16/28 via 10.0.1.10

### Test Nested VM Connectivity

From a nested VM (e.g., 10.0.1.20 on vme-kvm-vm1):

```bash
ping 10.0.1.10   # Its own KVM host
ping 10.0.1.11   # Other KVM host
ping 10.0.2.5    # Management subnet
```

All should work!

## Architecture

```
Nested VM (10.0.1.20)
  ↓ on OVS mgmt bridge
vme-kvm-vm1 (10.0.1.10)
  ↓ via eth1
Azure Network (knows 10.0.1.16/28 → 10.0.1.10)
  ↓ routes to
vme-kvm-vm2 (10.0.1.11)
  ↓ has route: 10.0.1.16/28 via 10.0.1.10
ICMP reply back through the same path
```

## Key Requirements

1. ✅ **IP forwarding enabled** on KVM hosts (`net.ipv4.ip_forward=1`)
2. ✅ **Azure NICs have IP forwarding enabled** (`enable_ip_forwarding=true`)
3. ✅ **UFW allows routed traffic** (`ufw default allow routed`)
4. ✅ **Azure Route Table** directs nested VM ranges to correct hosts
5. ✅ **Host routes** so each KVM host knows how to reach other hosts' nested VMs
6. ✅ **No NAT** - traffic flows with original source IPs

## Adding New KVM Hosts

1. Update `variables.tf` - add new IP ranges to `nested_vm_ip_ranges`
2. Run `terraform apply` - creates new Azure routes automatically
3. Run `setup-nested-vm-routes.sh` on all hosts - adds new routes
4. Use IPs from the assigned range for nested VMs on the new host

## Troubleshooting

### Nested VM can't reach other hosts

1. Check Azure routes are active:
   ```bash
   az network nic show-effective-route-table \
     --resource-group rg-hpe-vme-test \
     --name vme-kvm-vm1-vm-nic \
     --output table
   ```

2. Check host routes exist:
   ```bash
   ip route show | grep 10.0.1
   ```

3. Check IP forwarding:
   ```bash
   sysctl net.ipv4.ip_forward
   ```

4. Check UFW:
   ```bash
   ufw status verbose | grep routed
   ```

### Packets reaching destination but no reply

- Verify host routes on the destination KVM host
- Check destination host has route back to source VM's range

## Alternative Solutions (Not Implemented)

These approaches were considered but not used:

### Solution A: Secondary IPs (Not Scalable)

Add each nested VM's IP as a secondary IP configuration on the KVM host's NIC.

**Via Azure CLI:**
```bash
# Get your resource group and NIC name
RG="rg-ubuntu-vms"
NIC_NAME="ubuntu-vm1-vm-nic"

# Add secondary IP for nested VM
az network nic ip-config create \
  --resource-group $RG \
  --nic-name $NIC_NAME \
  --name nested-vm-1 \
  --private-ip-address 10.0.1.20 \
  --private-ip-address-version IPv4
```

**Via Terraform** (add to `main.tf`):
```terraform
# Secondary IP configurations for nested VMs on first KVM host
resource "azurerm_network_interface_ip_configuration" "vm_nic_secondary" {
  count                         = 5  # Number of nested VMs per host
  name                          = "nested-vm-${count.index + 1}"
  network_interface_id          = azurerm_network_interface.vm_nic[0].id
  subnet_id                     = azurerm_subnet.vm_subnet.id
  private_ip_address_allocation = "Static"
  private_ip_address            = "10.0.1.${20 + count.index}"
}
```

**Pros:**
- Clean solution
- Azure knows about all IPs
- Works without special routing

**Cons:**
- Max 256 secondary IPs per NIC (Azure limit)
- Must pre-allocate IPs
- Requires Terraform changes for new nested VMs

### Solution 2: NAT on KVM Hosts (Recommended for Dynamic/Many VMs)

Use NAT on the KVM host so all nested VM traffic appears to come from the KVM host's IP.

**For OVS-based setups (automated script):**
```bash
# Run the provided setup script
sudo bash setup-nested-vm-networking.sh

# Make iptables rules persistent
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

**Manual setup for OVS:**
```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Identify your physical NIC and OVS bridge
VM_NIC="eth1"           # Your VM traffic interface
OVS_BRIDGE="ovsbr0"     # Your OVS bridge name

# Setup NAT - traffic from OVS bridge goes out via physical NIC
sudo iptables -t nat -A POSTROUTING -o $VM_NIC -j MASQUERADE
sudo iptables -A FORWARD -i $OVS_BRIDGE -o $VM_NIC -j ACCEPT
sudo iptables -A FORWARD -i $VM_NIC -o $OVS_BRIDGE -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $OVS_BRIDGE -o $OVS_BRIDGE -j ACCEPT

# Make iptables rules persistent
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

**For Linux bridge setups:**
```bash
# Enable IP forwarding and NAT
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# Setup NAT (replace eth1 with your VM traffic interface)
VM_NIC="eth1"
sudo iptables -t nat -A POSTROUTING -o $VM_NIC -j MASQUERADE
sudo iptables -A FORWARD -i virbr0 -o $VM_NIC -j ACCEPT
sudo iptables -A FORWARD -i $VM_NIC -o virbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Make iptables rules persistent
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

**Pros:**
- Unlimited nested VMs
- No Azure configuration changes needed
- Dynamic IP allocation

**Cons:**
- Nested VMs can't receive inbound connections from outside their KVM host
- All traffic appears to come from KVM host IP (loses source IP visibility)
- More complex troubleshooting

### Solution 3: Azure Virtual Network Appliance (NVA) with Routes

Create routes that direct traffic for nested VM ranges to specific KVM hosts.

**Current Terraform already has:**
- IP forwarding enabled on NICs
- NSG rules allowing all VNet traffic
- ICMP enabled

**You need to add:**
```bash
az network route-table create \
  --resource-group $RG \
  --name nested-vm-routes

az network route-table route create \
  --resource-group $RG \
  --route-table-name nested-vm-routes \
  --name to-kvm-vm1-nested \
  --address-prefix 10.0.1.20/28 \
  --next-hop-type VirtualAppliance \
  --next-hop-ip-address 10.0.1.10

az network vnet subnet update \
  --resource-group $RG \
  --vnet-name ubuntu-vnet \
  --name ubuntu-vm-subnet \
  --route-table nested-vm-routes
```

**Pros:**
- Nested VMs can receive inbound traffic
- Source IPs preserved
- Proper routing table visibility

**Cons:**
- Fixed IP ranges per KVM host
- Requires planning IP allocation
- More complex initial setup

## Cross-Subnet Communication (10.0.1.x ↔ 10.0.2.x)

Your nested VMs need to reach the management subnet (10.0.2.0/24). This works automatically because:

1. Both subnets are in the same VNet (10.0.0.0/16)
2. NSG allows all VirtualNetwork-to-VirtualNetwork traffic
3. Azure's default routing handles inter-subnet communication

**No additional configuration needed** - nested VMs can reach management subnet IPs once they can route through their KVM host.

## Recommendation for Your Use Case

Given your requirements:
- Nested VMs need to talk to other KVM hosts (10.0.1.x)
- Nested VMs need to reach management subnet (10.0.2.x)
- Dynamic/flexible VM creation

**Use Solution 2 (NAT)** for simplicity, or **Solution 3 (Routes)** if you need inbound connectivity to nested VMs.

The current Terraform configuration has IP forwarding enabled and NSG rules in place. You just need to configure NAT or routes as documented above.
