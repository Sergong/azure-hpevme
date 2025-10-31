# Getting Started: Complete Deployment Guide

This guide walks you through deploying and configuring the complete HPE VM Essentials infrastructure on Azure, from initial setup to verification.

## Overview

This deployment creates:
- 2 Ubuntu KVM hosts with nested virtualization support
- 1 Windows Server 2022 jumphost for remote access
- Private DNS zone for internal name resolution
- Route tables for nested VM networking
- Complete networking with VNet, subnets, and NSGs

**Estimated Time**: 45-60 minutes

## Prerequisites

### 0. Download the HPE Essentials ISO
You will need to download the HPE Essentials software ISO (HPE_VM_Essentials_SW_image_v8.0.10_S5Q83-11027.iso) from HPE [Here](https://myenterpriselicense.hpe.com/cwp-ui/product-download-info/HPE_VME_EVAL/-/sw360_eval_customer)

From this ISO you will need to copy the following 2 files into this repo:
- [ ] hpe-vm-essentials-8.0.10-1.qcow2.gz
- [ ] hpe-vm_1.0.11-1_amd64.deb

The ansible playbook called `playbook-install-kvm.yml` will use these to upload them the KVM hosts.

### 1. Install Required Tools

#### Azure CLI
```bash
# macOS
brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Verify installation
az --version
```

#### Terraform
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform --version
```

#### Ansible
```bash
# macOS/Linux
pip3 install ansible

# Verify installation
ansible --version
```

### 2. Azure Authentication

```bash
# Login to Azure
az login

# (Optional) Set default subscription if you have multiple
az account list --output table
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify current subscription
az account show --output table
```

### 3. SSH Key Setup

```bash
# Generate SSH key pair (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "your_email@example.com"

# Verify key exists
ls -la ~/.ssh/id_rsa.pub
```

### 4. Get Your Public IP

You'll need your public IP to restrict SSH/RDP access:

```bash
# Get your current public IP
curl -s https://api.ipify.org
# or
curl -s https://ifconfig.me
```

Save this IP for the next step (e.g., `203.0.113.45`).

## Step 1: Configure Terraform Variables

### 1.1 Copy Example Configuration

```bash
cd /Users/smeeuwsen/projects/azure-hpevme
cp terraform.tfvars.example terraform.tfvars
```

### 1.2 Edit Configuration

Open `terraform.tfvars` and update these critical values:

```hcl
# Resource naming
resource_group_name = "rg-hpe-vme-test"
location            = "East US"
prefix              = "vme-kvm"

# VM configuration
vm_count            = 2
vm_size             = "Standard_E4as_v5"
admin_username      = "azureuser"

# SSH key path (update to your path)
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Security - UPDATE THIS WITH YOUR PUBLIC IP
my_public_ip        = "203.0.113.45/32"  # Replace with your IP from step 4

# DNS configuration
private_dns_zone_name = "hpevme.local"

# Windows jumphost
jumphost_vm_size        = "Standard_B2s"
jumphost_admin_username = "azureadmin"
# Note: Password will be prompted during terraform apply
```

### 1.3 Prepare Windows Jumphost Password

Create a strong password that meets Azure requirements:
- At least 12 characters
- Contains uppercase (A-Z)
- Contains lowercase (a-z)
- Contains numbers (0-9)
- Contains special characters (!@#$%^&*)

Example: `MyAzure2024Jump!Host`

## Step 2: Deploy Infrastructure with Terraform

### 2.1 Initialize Terraform

```bash
# Initialize Terraform (downloads providers)
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
...
Terraform has been successfully initialized!
```

### 2.2 Review Deployment Plan

```bash
# Create execution plan
terraform plan
```

You'll be prompted for the jumphost password:
```
var.jumphost_admin_password
  Admin password for Windows jumphost
  Enter a value: 
```

Review the plan to ensure it creates:
- 1 Resource Group
- 1 Virtual Network with 2 subnets
- 1 Private DNS Zone with 3 A records
- 1 Route Table with 2 routes
- 2 Network Security Groups
- 2 Linux VMs with 2 NICs each
- 1 Windows VM with 1 NIC
- 3 Public IPs
- 2 Data disks

### 2.3 Deploy Infrastructure

```bash
# Apply configuration
terraform apply
```

Enter the jumphost password again when prompted, then type `yes` to confirm.

**Deployment time**: ~10-15 minutes

### 2.4 Save Deployment Outputs

```bash
# View all outputs
terraform output

# Save important connection details
terraform output -json > deployment-info.json

# Get specific outputs
terraform output vm_public_ips
terraform output jumphost_public_ip
terraform output jumphost_rdp_command
```

## Step 3: Configure Ansible

### 3.1 Update Ansible Inventory

Edit `inventory.yml` to add the public IPs from Terraform output:

```bash
# Get the public IPs
terraform output vm_public_ips
terraform output jumphost_public_ip
```

Update `inventory.yml`:
```yaml
all:
  children:
    azure_vms:
      hosts:
        vme-kvm-vm1:
          ansible_host: <PUBLIC_IP_FROM_OUTPUT>  # Update this
          ansible_user: azureuser
        vme-kvm-vm2:
          ansible_host: <PUBLIC_IP_FROM_OUTPUT>  # Update this
          ansible_user: azureuser
      vars:
        ansible_ssh_private_key_file: ~/.ssh/id_rsa
        
    windows_jumphosts:
      hosts:
        jumphost:
          ansible_host: <JUMPHOST_PUBLIC_IP>  # Update this
          ansible_user: azureadmin
          ansible_password: "{{ vault_jumphost_password }}"
          ansible_connection: ssh
          ansible_shell_type: powershell
```

### 3.2 Configure Ansible Vault

Create a vault password file (never commit this!):

```bash
# Create vault password file
echo "your-strong-vault-password" > .vault_pass
chmod 600 .vault_pass

# Ensure it's in .gitignore
echo ".vault_pass" >> .gitignore
```

Create the vault directory and file:

```bash
# Create directory structure
mkdir -p group_vars/windows_jumphosts

# Create encrypted vault file
ansible-vault create group_vars/windows_jumphosts/vault.yml
```

When prompted for vault password, use the one from `.vault_pass`. Then add:

```yaml
vault_jumphost_password: YourWindowsJumphostPassword123!
```

Save and exit (`:wq` in vim).

### 3.3 Test Ansible Connectivity

```bash
# Test Linux VMs
ansible azure_vms -m ping

# Test Windows jumphost
ansible windows_jumphosts -m win_ping
```

Expected output:
```
vme-kvm-vm1 | SUCCESS => {
    "ping": "pong"
}
vme-kvm-vm2 | SUCCESS => {
    "ping": "pong"
}
jumphost | SUCCESS => {
    "ping": "pong"
}
```

If this fails, see [Troubleshooting](#troubleshooting-ansible-connectivity).

## Step 4: Configure Linux KVM Hosts

### 4.1 Install KVM and Configure Networking

This playbook installs KVM, configures OpenVSwitch, and sets up routing:

```bash
ansible-playbook playbook-install-kvm.yml
```

**Duration**: ~15-20 minutes

This playbook will:
- ✅ Install KVM/QEMU packages
- ✅ Install HPE VM Essentials package
- ✅ Configure OpenVSwitch bridge on eth1
- ✅ Set up static IPs via netplan
- ✅ Configure nested VM routing
- ✅ Set up NAT for internet access
- ✅ Format and mount data disks

### 4.2 Configure DNS on Linux Hosts

```bash
ansible-playbook playbook-configure-dns.yml
```

This configures DNS search domains for `hpevme.local` resolution.

### 4.3 Verify Linux Host Configuration

```bash
# Check KVM installation
ansible azure_vms -m shell -a "virsh version"

# Check OVS bridge
ansible azure_vms -m shell -a "ovs-vsctl show"

# Check routing
ansible azure_vms -m shell -a "ip route | grep 10.0.1"

# Check DNS resolution
ansible azure_vms -m shell -a "host vme-kvm-vm1.hpevme.local"
ansible azure_vms -m shell -a "host jumphost.hpevme.local"

# Check disk mount
ansible azure_vms -m shell -a "df -h /data"
```

## Step 5: Configure Windows Jumphost

### 5.1 Configure DNS on Windows

```bash
ansible-playbook playbook-configure-windows-dns.yml
```

This configures the DNS suffix search list for `hpevme.local`.

### 5.2 Install PuTTY

```bash
ansible-playbook playbook-install-putty.yml
```

This installs PuTTY for SSH access to Linux VMs from the jumphost.

### 5.3 Configure Windows Firewall

```bash
ansible-playbook playbook-configure-jumphost-firewall.yml
```

This enables ICMP (ping) on the Windows firewall.

### 5.4 Verify Windows Configuration

```bash
# Test DNS resolution
ansible windows_jumphosts -m win_shell -a "nslookup vme-kvm-vm1.hpevme.local"
ansible windows_jumphosts -m win_shell -a "nslookup vme-kvm-vm2-traffic.hpevme.local"

# Test ping to Linux hosts
ansible windows_jumphosts -m win_shell -a "Test-NetConnection -ComputerName 10.0.2.5 -InformationLevel Quiet"

# Verify PuTTY installation
ansible windows_jumphosts -m win_shell -a "Test-Path 'C:\\Program Files\\PuTTY\\putty.exe'"
```

## Step 6: Deploy HPE VM Essential Manager VM on vme-kvm-vm1 host
In this step you will need to deploy the HPE VM Essential Manager VM you do this by running the following command on the **vme-kvm-vm1** host:
```
sudo hpe-vm
```
Refer to the HPE documentation but you should only need to select the `Install VME Manager option` and complete the fields.

## Step 7: Verify Complete Deployment

### 7.1 DNS Resolution Test

From your local machine:

```bash
# SSH to first KVM host
ssh azureuser@$(terraform output -raw vm_public_ips | jq -r '.[0]')

# Test DNS resolution
host vme-kvm-vm1.hpevme.local
host vme-kvm-vm2.hpevme.local
host vme-kvm-vm1-traffic.hpevme.local
host vme-kvm-vm2-traffic.hpevme.local
host jumphost.hpevme.local
host hpevme.hpevme.local

# Test connectivity
ping -c 2 vme-kvm-vm2.hpevme.local
ping -c 2 jumphost.hpevme.local
```

### 7.2 Network Connectivity Test

```bash
# Test cross-host connectivity
ping -c 2 10.0.1.11  # Other KVM host traffic interface
ping -c 2 10.0.2.100  # Jumphost

# Test routing to nested VM ranges
ip route | grep 10.0.1

# Test NAT for internet
ping -c 2 8.8.8.8
curl -I https://www.google.com
```

### 7.3 Windows Jumphost RDP Test

From your local machine:

#### macOS
```bash
# Get RDP command
terraform output jumphost_rdp_command

# Install Microsoft Remote Desktop from App Store
# Create new connection with the public IP
# Username: azureadmin
# Password: Your jumphost password
```

#### Windows
```bash
# Get RDP command
terraform output jumphost_rdp_command

# Run Remote Desktop Connection
mstsc /v:<jumphost_public_ip>
```

#### Linux
```bash
# Install xfreerdp
sudo apt install freerdp2-x11

# Connect
xfreerdp /u:azureadmin /v:<jumphost_public_ip>
```

Once connected to the jumphost:
1. Open PowerShell
2. Test DNS: `nslookup vme-kvm-vm1.hpevme.local`
3. Test connectivity: `ping vme-kvm-vm1-traffic.hpevme.local`
4. Open PuTTY and connect to `vme-kvm-vm1.hpevme.local`

## Step 8: Create Test Nested VM (Optional)

### 8.1 Prepare Nested VM Image

```bash
# SSH to vme-kvm-vm1
ssh azureuser@<vm1_public_ip>

# Check if HPE VM Essentials image exists
ls -lh /data/hpe-vm-essentials*.qcow2.gz

# If not, download or copy your image
# Example: scp from local machine
# scp hpe-vm-essentials-8.0.10-1.qcow2.gz azureuser@<vm1_public_ip>:/data/

# Extract if needed
cd /data
gunzip hpe-vm-essentials-8.0.10-1.qcow2.gz
```

### 8.2 Create Nested VM

```bash
# Create VM with virt-install
sudo virt-install \
  --name hpevme \
  --memory 4096 \
  --vcpus 2 \
  --disk /data/hpe-vm-essentials-8.0.10-1.qcow2,bus=virtio \
  --import \
  --network bridge=mgmt,model=virtio \
  --graphics vnc,listen=0.0.0.0 \
  --noautoconsole

# List VMs
sudo virsh list --all

# Get console access
sudo virsh console hpevme
```

### 8.3 Configure Nested VM Network

Inside the nested VM console:

```bash
# Configure static IP (from allocated range 10.0.1.16-31)
ip addr add 10.0.1.20/24 dev eth0
ip link set eth0 up

# Add default gateway (KVM host traffic IP)
ip route add default via 10.0.1.10

# Configure DNS
echo "nameserver 168.63.129.16" > /etc/resolv.conf
echo "search hpevme.local" >> /etc/resolv.conf

# Test connectivity
ping -c 2 10.0.1.10  # KVM host
ping -c 2 10.0.1.11  # Other KVM host
ping -c 2 8.8.8.8    # Internet
ping -c 2 google.com # DNS resolution
```

### 8.4 Test Nested VM from Jumphost

1. RDP to Windows jumphost
2. Open browser (Edge/Chrome/Firefox)
3. Navigate to `http://10.0.1.20` (or `http://hpevme.hpevme.local`)
4. You should see the HPE VM Essentials web interface

## Architecture Summary

After deployment, you'll have:

```
Internet
   |
   └── Azure Public IPs
        |
        ├── vme-kvm-vm1 (Public IP) ──┐
        ├── vme-kvm-vm2 (Public IP) ──┤── SSH Access (Port 22)
        └── jumphost (Public IP) ─────┘── RDP Access (Port 3389)
                |
                └── Azure VNet (10.0.0.0/16)
                     |
                     ├── Management Subnet (10.0.2.0/24)
                     │    ├── vme-kvm-vm1 (10.0.2.5)
                     │    ├── vme-kvm-vm2 (10.0.2.4)
                     │    └── jumphost (10.0.2.100)
                     │
                     └── VM Traffic Subnet (10.0.1.0/24)
                          ├── vme-kvm-vm1 (10.0.1.10) ──> Nested VMs: 10.0.1.16-31
                          ├── vme-kvm-vm2 (10.0.1.11) ──> Nested VMs: 10.0.1.48-63
                          └── jumphost (10.0.1.100)
```

**DNS Resolution:**
- All hostnames resolve via `hpevme.local` private DNS zone
- Works automatically within the VNet
- No external DNS configuration needed

**Routing:**
- Azure Route Tables direct nested VM traffic to correct KVM hosts
- NAT provides internet access for nested VMs
- Full cross-subnet communication enabled

## Daily Operations

### Connect to VMs

```bash
# SSH to KVM hosts
ssh azureuser@$(terraform output -raw vm_public_ips | jq -r '.[0]')

# RDP to jumphost
terraform output jumphost_rdp_command
```

### Manage Nested VMs

```bash
# List VMs
sudo virsh list --all

# Start VM
sudo virsh start hpevme

# Stop VM
sudo virsh shutdown hpevme

# Force stop VM
sudo virsh destroy hpevme

# Remove VM
sudo virsh undefine hpevme
```

### Check Resources

```bash
# Check disk space
df -h /data

# Check memory
free -h

# Check CPU
lscpu

# Check network
ip addr
ovs-vsctl show
```

### Update Configuration

```bash
# Re-run specific playbook
ansible-playbook playbook-install-kvm.yml

# Update just routing
ansible all -m copy -a 'src=setup-nested-vm-routes.sh dest=/tmp/setup-nested-vm-routes.sh mode=0755'
ansible all -m shell -a 'sudo /tmp/setup-nested-vm-routes.sh'
```

## Troubleshooting

### Troubleshooting: Ansible Connectivity

**Problem**: `ansible azure_vms -m ping` fails

**Solutions**:

1. **Check SSH connectivity manually:**
   ```bash
   ssh -i ~/.ssh/id_rsa azureuser@<vm_public_ip>
   ```

2. **Verify inventory file has correct IPs:**
   ```bash
   ansible-inventory --list
   ```

3. **Check NSG allows your current IP:**
   ```bash
   # Get your current public IP
   curl https://ifconfig.me
   
   # Update NSG if your IP changed
   # Edit terraform.tfvars with new IP and run:
   terraform apply
   ```

4. **Test with verbose output:**
   ```bash
   ansible azure_vms -m ping -vvv
   ```

### Troubleshooting: Terraform Apply Fails

**Problem**: Terraform apply fails with authentication error

**Solution**:
```bash
# Re-login to Azure
az login
az account show

# Verify subscription
az account list --output table
```

**Problem**: Resource name already exists

**Solution**:
```bash
# Update prefix in terraform.tfvars
prefix = "vme-kvm-unique-name"

# Re-apply
terraform apply
```

### Troubleshooting: DNS Resolution

**Problem**: Can't resolve `*.hpevme.local` hostnames

**Solution**:
```bash
# Re-run DNS configuration
ansible-playbook playbook-configure-dns.yml
ansible-playbook playbook-configure-windows-dns.yml

# Manually check DNS
host -t A vme-kvm-vm1.hpevme.local 168.63.129.16
```

### Troubleshooting: Nested VM Internet Access

**Problem**: Nested VM can't reach internet

**Solution**:
```bash
# Check NAT configuration
ansible all -m shell -a "sudo iptables -t nat -L -n -v"

# Re-apply NAT configuration
ansible all -m copy -a 'src=setup-nested-vm-nat.sh dest=/tmp/setup-nested-vm-nat.sh mode=0755'
ansible all -m shell -a 'sudo /tmp/setup-nested-vm-nat.sh'
```

See [TROUBLESHOOTING-INTERNET.md](TROUBLESHOOTING-INTERNET.md) for detailed troubleshooting.

### Troubleshooting: Windows Jumphost

**Problem**: Can't RDP to jumphost

**Solution**:
```bash
# Check NSG allows your IP
terraform output jumphost_details

# Verify VM is running
az vm get-instance-view \
  --resource-group rg-hpe-vme-test \
  --name vme-kvm-jumphost \
  --query instanceView.statuses[1].displayStatus
```

**Problem**: Can't ping jumphost from Linux VMs

**Solution**:
```bash
# Enable ICMP on Windows Firewall
ansible-playbook playbook-configure-jumphost-firewall.yml
```

## Cost Management

### Monthly Cost Estimate (East US pricing)

| Resource | Size | Monthly Cost (approx) |
|----------|------|----------------------|
| 2x Linux VMs | Standard_E4as_v5 | ~$260/month |
| 1x Windows VM | Standard_B2s | ~$35/month |
| 2x Data Disks | 1TB HDD | ~$40/month |
| 3x Public IPs | Standard | ~$9/month |
| Networking | VNet/DNS | Minimal |
| **Total** | | **~$344/month** |

### Cost Optimization

1. **Deallocate VMs when not in use:**
   ```bash
   # Stop all VMs (stops compute charges)
   az vm deallocate --ids $(az vm list -g rg-hpe-vme-test --query "[].id" -o tsv)
   
   # Start VMs when needed
   az vm start --ids $(az vm list -g rg-hpe-vme-test --query "[].id" -o tsv)
   ```

2. **Use Azure Dev/Test pricing** if eligible

3. **Downgrade VM sizes** if performance allows:
   ```hcl
   # In terraform.tfvars
   vm_size = "Standard_D2as_v5"  # 2 vCPUs, 8GB RAM (~$80/month)
   ```

4. **Schedule auto-shutdown** in Azure Portal

## Cleanup

### Destroy All Resources

**WARNING**: This permanently deletes all VMs, disks, and data!

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy

# Confirm by typing 'yes'
```

### Partial Cleanup

To remove only specific resources, use `terraform state rm`:

```bash
# Remove jumphost only
terraform state rm azurerm_windows_virtual_machine.jumphost
terraform state rm azurerm_network_interface.jumphost_nic
terraform state rm azurerm_public_ip.jumphost_public_ip
```

## Next Steps

- **Learn More**:
  - [README.md](README.md) - Complete infrastructure documentation
  - [NESTED-VM-NETWORKING.md](NESTED-VM-NETWORKING.md) - Nested VM networking details
  - [JUMPHOST.md](JUMPHOST.md) - Windows jumphost configuration
  - [TROUBLESHOOTING-INTERNET.md](TROUBLESHOOTING-INTERNET.md) - Internet connectivity issues

- **Customize**:
  - Add more KVM hosts by increasing `vm_count`
  - Change VM sizes for different performance needs
  - Add custom Ansible playbooks for additional configuration

- **Production**:
  - Use Azure Bastion instead of public IPs
  - Implement Azure Backup for VMs
  - Set up Azure Monitor and Log Analytics
  - Use Azure Key Vault for secrets management
  - Implement Just-In-Time VM access

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the detailed documentation files
3. Check Terraform and Ansible logs
4. Verify Azure resource status in Azure Portal

## Summary

You now have a fully functional HPE VM Essentials environment with:
- ✅ 2 KVM hosts with nested virtualization
- ✅ Windows jumphost for remote access
- ✅ Private DNS for internal name resolution
- ✅ Route tables for nested VM networking
- ✅ NAT for internet access
- ✅ Complete monitoring and management tools

Happy virtualizing! 🚀
