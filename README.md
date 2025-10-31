# HPE VM Essentials on Azure - KVM Host Setup

This Terraform project creates KVM hosts on Azure for running HPE VM Essentials with support for nested VMs across multiple hosts.

## Architecture

The project creates:
- **Resource Group** for all resources
- **Virtual Network** (10.0.0.0/16) with:
  - **VM Traffic Subnet** (10.0.1.0/24) - For KVM hosts and nested VMs
  - **Management Subnet** (10.0.2.0/24) - For public IP access and management
- **Private DNS Zone** (`hpevme.local`) with:
  - Auto-registration for VM management interfaces
  - Manual A records for traffic interfaces and nested VMs
  - Automatic DNS resolution within the VNet
- **Route Table** with routes for nested VM IP ranges
- **Network Security Groups**:
  - **Linux VMs NSG**: SSH access restricted to your public IP, full VNet communication
  - **Windows Jumphost NSG**: RDP and SSH access restricted to your public IP
- **Public IP addresses** (Standard SKU, Static)
- **Network Interfaces** with IP forwarding enabled:
  - Management NIC (primary, has public IP)
  - VM Traffic NIC (secondary, for nested VM traffic)
- **SSH Key resource**
- **1TB data disks** (Standard HDD) for each host
- **Lifecycle Management**: VMs configured with `ignore_changes` for `custom_data` to prevent unnecessary replacement during infrastructure updates
- **KVM Host VMs** (Ubuntu 24.04 LTS, Standard_E4as_v5) with:
  - KVM/QEMU virtualization packages
  - OpenVSwitch for nested VM networking
  - Configured OVS bridge (`mgmt`) on eth1
- **Windows Jumphost** (Windows Server 2022, Standard_B2s) with:
  - OpenSSH Server for Ansible management
  - PuTTY for SSH access to Linux VMs
  - Configured DNS suffix for private DNS resolution

## Prerequisites

1. **Azure CLI**: Ensure you have the Azure CLI installed and are logged in:
   ```bash
   az login
   ```

2. **Terraform**: Install Terraform (version 1.0 or later)

3. **SSH Key**: Generate an SSH key pair if you don't have one:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   ```

## Quick Start

1. **Clone or download this project** to your local machine.

2. **Copy the example variables file**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit terraform.tfvars** with your desired values:
   - Update `ssh_public_key_path` to point to your SSH public key
   - Modify other variables as needed (resource names, location, etc.)

4. **Initialize Terraform**:
   ```bash
   terraform init
   ```

5. **Plan the deployment**:
   ```bash
   terraform plan
   ```

6. **Apply the configuration**:
   ```bash
   terraform apply
   ```

7. **Connect to your VMs**:
   After deployment, use the SSH commands from the output:
   ```bash
   ssh azureuser@<public-ip-address>
   ```

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `resource_group_name` | Name of the Azure Resource Group | `rg-ubuntu-vms` | No |
| `location` | Azure region | `East US` | No |
| `prefix` | Prefix for resource names | `ubuntu` | No |
| `vm_count` | Number of VMs to create | `2` | No |
| `vm_size` | VM SKU for Linux KVM hosts | `Standard_E4as_v5` | No |
| `admin_username` | Admin username for Linux VMs | `azureuser` | No |
| `ssh_public_key_path` | Path to SSH public key | `~/.ssh/id_rsa.pub` | No |
| `jumphost_vm_size` | VM SKU for Windows jumphost | `Standard_B2s` | No |
| `jumphost_admin_username` | Admin username for Windows jumphost | `azureadmin` | No |
| `jumphost_admin_password` | Admin password for Windows jumphost | - | Yes |
| `my_public_ip` | Your public IP for NSG whitelist | `193.237.155.169/32` | No |
| `private_dns_zone_name` | Private DNS zone name | `hpevme.local` | No |
| `tags` | Tags for all resources | See variables.tf | No |

## Outputs

After deployment, Terraform will output:
- Resource group name
- VM names
- Private IP addresses
- Public IP addresses
- SSH connection commands
- Data disk names
- Detailed VM information (including storage details)

## VM Specifications

- **OS**: Ubuntu 24.04 LTS (Noble)
- **SKU**: Standard_E4as_v5 (4 vCPUs, 32 GB RAM)
- **Nested Virtualization**: Supported (can run VMs inside the VM)
- **OS Disk**: Standard HDD (ReadWrite caching)
- **Data Disk**: 1TB Standard HDD mounted at `/data` (automatically formatted and mounted)
- **Network**: Each VM has a public IP and is accessible via SSH
- **Security**: Password authentication disabled, SSH key authentication only

## Security Features

- **Network Security Groups** with IP-restricted access:
  - **Linux VMs NSG**: SSH (port 22) from your public IP only
  - **Windows Jumphost NSG**: RDP (port 3389) and SSH (port 22) from your public IP only
  - Full VNet-to-VNet communication allowed
- **Linux VMs**: Password authentication disabled, SSH key-based authentication only
- **Windows Jumphost**: OpenSSH Server with password authentication for Ansible management
- **Private DNS Zone**: Internal name resolution without exposing to public internet

## Post-Deployment

### Linux KVM Hosts

Each Linux VM comes with:
- **KVM/Virtualization packages** installed:
  - qemu-kvm, libvirt, virtinst, OpenVSwitch
  - Pacemaker, Corosync, Ceph for clustering
- **HPE VM Essentials package** installed (hpe-vm_1.0.11-1_amd64.deb)
- **OVS Bridge** configured:
  - Bridge name: `mgmt`
  - Connected to eth1 interface
  - Configured via netplan with static IP
- **DNS Configuration**:
  - Private DNS zone: `hpevme.local`
  - Search domains configured for internal name resolution
- **1TB data disk** automatically formatted (ext4) and mounted at `/data`
- **Nested VM routing** configured for cross-host communication
- **NAT configured** for nested VM internet access

### Windows Jumphost

The Windows jumphost comes with:
- **OpenSSH Server** installed and configured
- **PuTTY** installed via Chocolatey
- **DNS suffix** configured for `hpevme.local` resolution
- **Accessible via RDP** from your public IP
- **Accessible via SSH** for Ansible management

### DNS Hostnames

All VMs are accessible via internal DNS (`hpevme.local` private DNS zone):

| Hostname | IP Address | Type | Description |
|----------|------------|------|-------------|
| `vme-kvm-vm1.hpevme.local` | 10.0.2.5 | Auto-registered | KVM host 1 management interface |
| `vme-kvm-vm1-traffic.hpevme.local` | 10.0.1.10 | Manual A record | KVM host 1 traffic interface |
| `vme-kvm-vm2.hpevme.local` | 10.0.2.4 | Auto-registered | KVM host 2 management interface |
| `vme-kvm-vm2-traffic.hpevme.local` | 10.0.1.11 | Manual A record | KVM host 2 traffic interface |
| `jumphost.hpevme.local` | 10.0.2.100 | Auto-registered | Windows jumphost |
| `hpevme.hpevme.local` | 10.0.1.20 | Manual A record | Example nested VM hostname |

**DNS Configuration:**
- **Auto-registration**: VM NICs in management subnet automatically register their hostnames
- **Manual A records**: Traffic interfaces and nested VM hostnames are created via Terraform
- **DNS Search Domain**: All VMs have `hpevme.local` configured as a search domain
- **Resolution**: Works automatically within the VNet without additional configuration

### Ansible Inventory

An Ansible inventory file (`inventory.yml`) is provided with:
- **azure_vms** group: Linux KVM hosts
- **windows_jumphosts** group: Windows jumphost
- Configured with proper SSH settings and passwords (via Ansible Vault)

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Customization

You can modify the project to:
- Change the VM count (set `vm_count` variable)
- Use different VM sizes
- Add additional security rules
- Install different software via cloud-init
- Create VMs in different subnets

## Troubleshooting

1. **SSH Key Issues**: Ensure your SSH public key file exists and is readable
2. **Azure Authentication**: Make sure you're logged in with `az login`
3. **Resource Naming**: Azure resource names must be globally unique in some cases
4. **Quota Limits**: Ensure your Azure subscription has sufficient quota for the VM size

## Files Structure

```
├── main.tf                           # Main Terraform configuration
├── variables.tf                      # Variable definitions
├── outputs.tf                        # Output definitions
├── terraform.tfvars.example          # Example variables file
├── inventory.yml                     # Ansible inventory
├── playbook-install-kvm.yml          # Ansible playbook for KVM setup
├── playbook-install-putty.yml        # Ansible playbook for PuTTY installation
├── playbook-configure-dns.yml        # Ansible playbook for DNS configuration
├── playbook-configure-windows-dns.yml # Ansible playbook for Windows DNS
├── playbook-configure-jumphost-firewall.yml # Ansible playbook for jumphost firewall
├── netplan-static.yaml.j2            # Netplan template for static IPs
├── netplan-with-ovs.yaml.j2          # Netplan template with OVS bridge
├── setup-nested-vm-routes.sh         # Script for nested VM routing
├── setup-nested-vm-nat.sh            # Script for NAT configuration
├── group_vars/windows_jumphosts/     # Ansible vault for Windows password
└── README.md                         # This file
```

## Ansible Management

### Prerequisites

1. **Ansible installed**:
   ```bash
   pip install ansible
   ```

2. **Ansible Vault password** configured:
   ```bash
   # Create vault password file (recommended)
   echo "your-vault-password" > .vault_pass
   chmod 600 .vault_pass
   echo ".vault_pass" >> .gitignore
   
   # Or create vault interactively
   ansible-vault create group_vars/windows_jumphosts/vault.yml
   ```

3. **Set Windows jumphost password** in vault:
   ```yaml
   # In group_vars/windows_jumphosts/vault.yml
   vault_jumphost_password: YourWindowsPassword
   ```

### Available Playbooks

#### 1. Install KVM and Configure Networking
```bash
ansible-playbook playbook-install-kvm.yml
```

This playbook:
- Installs KVM/QEMU and virtualization packages
- Configures OpenVSwitch bridge for nested VMs
- Sets up static IPs via netplan
- Configures nested VM routing and NAT
- Installs HPE VM Essentials package

#### 2. Install PuTTY on Windows Jumphost
```bash
ansible-playbook playbook-install-putty.yml
```

This playbook:
- Installs Chocolatey package manager
- Installs PuTTY via Chocolatey
- Verifies installation

#### 3. Configure DNS on Linux VMs
```bash
ansible-playbook playbook-configure-dns.yml
```

This playbook:
- Configures DNS search domains for `hpevme.local`
- Sets up persistent DNS configuration
- Verifies DNS resolution

#### 4. Configure DNS on Windows Jumphost
```bash
ansible-playbook playbook-configure-windows-dns.yml
```

This playbook:
- Configures DNS suffix search list
- Flushes DNS cache
- Tests DNS resolution

#### 5. Configure Windows Jumphost Firewall
```bash
ansible-playbook playbook-configure-jumphost-firewall.yml
```

This playbook:
- Enables ICMP (ping) on Windows Firewall
- Creates firewall rule for inbound ICMP Echo Requests
- Verifies firewall rule creation
- Allows testing connectivity to jumphost from Linux VMs

### Ad-hoc Ansible Commands

```bash
# Check connectivity to all hosts
ansible all -m ping

# Check Linux VMs only
ansible azure_vms -m ping

# Check Windows jumphost only
ansible windows_jumphosts -m win_ping

# Run shell command on all Linux VMs
ansible azure_vms -m shell -a "uptime"

# Get IP addresses
ansible azure_vms -m shell -a "ip addr"
```

## Storage Configuration

### OS Disk
- **Type**: Standard HDD (Standard_LRS)
- **Size**: Default (typically 30GB for Ubuntu 24.04)
- **Caching**: ReadWrite

### Data Disk
- **Type**: Standard HDD (Standard_LRS)
- **Size**: 1TB (1024GB)
- **Mount Point**: `/data`
- **File System**: ext4
- **Caching**: ReadWrite
- **Auto-Mount**: Yes (configured in `/etc/fstab`)

### Data Disk Usage

After deployment, you can use the data disk:

```bash
# Check disk space
df -h /data

# View disk setup log
sudo cat /var/log/disk-setup.log

# Use the data directory
cd /data
```

## HPE VME Repository Configuration

The VMs are automatically configured with HPE VME repositories:

### Configured Repositories
1. **HPE Private Ubuntu Repository**:
   - URL: `https://update1.linux.hpe.com/repo/hpevme/zion-private-ubuntu/`
   - Suite: `pulp`
   - Components: `upload`

2. **HPE OS Updates Repository**:
   - URL: `https://update1.linux.hpe.com/repo/hpevme/zion-os-updates-prod/ubuntu2404-os-updates/`
   - Suite: `noble-updates` 
   - Components: `main`

### Repository Management

```bash
# View configured HPE repositories
sudo cat /etc/apt/sources.list.d/hpe-ubuntu.sources

# Check HPE repository setup log
sudo cat /var/log/hpe-repo-setup.log

# Update package lists (including HPE repos)
sudo apt update

# Search for HPE packages
apt search hpe
```

### Repository Configuration Details
- **Format**: DEB822 format (`.sources` file)
- **Trust**: Repositories are marked as trusted
- **Validation**: Check-Valid-Until is disabled
- **Location**: `/etc/apt/sources.list.d/hpe-ubuntu.sources`

## VM Sizes Reference

The Standard_E4as_v5 VM includes:
- 4 vCPUs
- 32 GB RAM
- 64 GB temporary storage
- **Nested virtualization support** (can run KVM/QEMU VMs)
- Standard and Premium storage support
- AMD EPYC processors

## Nested VM Networking

This setup supports nested VMs running on KVM hosts that can communicate across hosts using Azure Route Tables.

### IP Allocation

- **KVM Hosts**: 10.0.1.10-19
  - vme-kvm-vm1: 10.0.1.10
  - vme-kvm-vm2: 10.0.1.11
  
- **Nested VMs**:
  - On vme-kvm-vm1: 10.0.1.16-31 (/28)
  - On vme-kvm-vm2: 10.0.1.48-63 (/28)
  - Future hosts get additional /28 ranges

### How It Works

1. **Azure Route Tables** tell Azure which KVM host owns which nested VM IP range
2. **KVM Host Routes** allow each host to reach nested VMs on other hosts
3. **No NAT** - nested VMs use their actual IPs throughout the network
4. **OVS Bridge** (`mgmt`) connects nested VMs to the physical network

### Setup

After deploying with Terraform:

```bash
# 1. Configure KVM host routes
ansible all -m copy -a 'src=setup-nested-vm-routes.sh dest=/tmp/setup-nested-vm-routes.sh mode=0755'
ansible all -m shell -a 'sudo /tmp/setup-nested-vm-routes.sh'

# 2. Configure UFW firewall
ansible all -m shell -a 'sudo ufw default allow routed'
ansible all -m shell -a 'sudo ufw allow in on eth0 to any port 22'
ansible all -m shell -a 'sudo ufw reload'
```

### Creating Nested VMs

When creating nested VMs, use IPs from the host's allocated range:

```bash
# On vme-kvm-vm1, use 10.0.1.16-31
# Inside nested VM:
ip addr add 10.0.1.20/24 dev eth0
ip route add default via 10.0.1.10  # Gateway is the KVM host
```

See [NESTED-VM-NETWORKING.md](NESTED-VM-NETWORKING.md) for complete details.

## Consistent Disk Naming for Ceph

Azure VMs can have inconsistent device names for data disks:
- **vme-kvm-vm1**: Data disk is `/dev/sdb`
- **vme-kvm-vm2**: Data disk is `/dev/sda`

For Ceph OSDs, which require consistent device paths, we use **udev rules** to create stable symlinks:

```bash
# Setup consistent naming
ansible-playbook playbook-setup-consistent-disk-naming.yml

# Verify
ansible azure_vms -m shell -a "ls -la /dev/azure-data"
```

This creates `/dev/azure-data` on all hosts pointing to the 1TB data disk (LUN 10), regardless of whether the underlying device is `/dev/sda` or `/dev/sdb`.

**For Ceph:**
```bash
# Use the stable symlink for OSD creation
ceph-volume lvm create --data /dev/azure-data
```

See [CEPH-DISK-SETUP.md](CEPH-DISK-SETUP.md) for complete details.
