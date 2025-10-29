# HPE VM Essentials on Azure - KVM Host Setup

This Terraform project creates KVM hosts on Azure for running HPE VM Essentials with support for nested VMs across multiple hosts.

## Architecture

The project creates:
- **Resource Group** for all resources
- **Virtual Network** (10.0.0.0/16) with:
  - **VM Traffic Subnet** (10.0.1.0/24) - For KVM hosts and nested VMs
  - **Management Subnet** (10.0.2.0/24) - For public IP access and management
- **Route Table** with routes for nested VM IP ranges
- **Network Security Group** with rules for SSH, HTTP, HTTPS, ICMP, and VNet traffic
- **Public IP addresses** (Standard SKU, Static)
- **Network Interfaces** with IP forwarding enabled:
  - Management NIC (primary, has public IP)
  - VM Traffic NIC (secondary, for nested VM traffic)
- **SSH Key resource**
- **1TB data disks** (Standard HDD) for each host
- **KVM Host VMs** (Ubuntu 24.04 LTS, Standard_E4as_v5)

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
| `vm_size` | VM SKU | `Standard_E4as_v5` | No |
| `admin_username` | Admin username for VMs | `azureuser` | No |
| `ssh_public_key_path` | Path to SSH public key | `~/.ssh/id_rsa.pub` | No |
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

- Network Security Group with controlled inbound rules:
  - SSH (port 22)
  - HTTP (port 80)
  - HTTPS (port 443)
- Password authentication disabled
- SSH key-based authentication only

## Post-Deployment

Each VM comes with:
- HPE VME repositories configured and enabled:
  - `https://update1.linux.hpe.com/repo/hpevme/zion-private-ubuntu/`
  - `https://update1.linux.hpe.com/repo/hpevme/zion-os-updates-prod/ubuntu2404-os-updates/`
- Updated package repositories (including HPE repos)
- Basic tools installed (curl, wget, git, vim, htop, tree)
- 1TB data disk automatically formatted (ext4) and mounted at `/data`
- Custom welcome message with data disk information

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
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output definitions
├── terraform.tfvars.example   # Example variables file
└── README.md                  # This file
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
