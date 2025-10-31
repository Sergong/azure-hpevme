# Windows Jumphost Configuration

## Overview

A Windows Server 2022 jumphost VM has been added to the infrastructure to provide browser-based access to nested VMs running on the KVM hosts. This jumphost is deployed in the `10.0.1.0/24` subnet, allowing it to directly access nested VMs including the one at `10.0.1.20`.

## Architecture

```
Internet
   │
   └──> Windows Jumphost (10.0.1.100)
           │
           └──> Nested VM (10.0.1.20) - Web Application
                 │
                 └──> Hosted on vme-kvm-vm1 (10.0.1.10)
```

## Configuration

### IP Addressing
- **Private IP**: `10.0.1.100` (in VM subnet)
- **Public IP**: Dynamically assigned (accessible via RDP)
- **Subnet**: `10.0.1.0/24` (same subnet as nested VMs)
- **Target VM**: `10.0.1.20` (nested VM with web application)

### VM Specifications
- **OS**: Windows Server 2022 Datacenter
- **Size**: `Standard_B2s` (2 vCPUs, 4GB RAM)
- **Admin Username**: `azureadmin` (configurable via `jumphost_admin_username`)
- **Admin Password**: Set via `jumphost_admin_password` in `terraform.tfvars`

### Network Connectivity
The jumphost has direct Layer 3 connectivity to:
- All KVM host management interfaces (`10.0.2.0/24`)
- All nested VM IP ranges:
  - `10.0.1.16/28` - vme-kvm-vm1 nested VMs (includes 10.0.1.20)
  - `10.0.1.48/28` - vme-kvm-vm2 nested VMs
  - Additional ranges for future KVM hosts

### Security
- **RDP Access**: Port 3389 open via NSG
- **HTTP/HTTPS**: Ports 80/443 open for accessing nested VM web applications
- **VNet Traffic**: Full access to all subnets in the VNet

## Deployment

### 1. Password Prompt

Terraform will **prompt you for the jumphost password** during `plan` and `apply`. The password is not stored in any configuration files for security.

**Password Requirements:**
- At least 12 characters
- Contains uppercase letters (A-Z)
- Contains lowercase letters (a-z)
- Contains numbers (0-9)
- Contains special characters (!@#$%^&*)

**Example:**
```bash
terraform plan
# You'll see:
# var.jumphost_admin_password
#   Admin password for Windows jumphost (must meet Azure complexity requirements: 12+ chars with upper, lower, number, and special character)
#   Enter a value:
```

### 2. Optional Configuration

You can customize these variables in `terraform.tfvars`:

```hcl
jumphost_ip             = "10.0.1.100"      # Private IP in 10.0.1.0/24
jumphost_vm_size        = "Standard_B2s"    # VM size
jumphost_admin_username = "azureadmin"      # Admin username
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan  # You'll be prompted for the password
terraform apply # You'll be prompted again
```

**Tip:** To avoid entering the password twice, save your plan:
```bash
terraform plan -out=tfplan
terraform apply tfplan  # Uses saved plan, no password prompt
```

### 3. Get Connection Details

After deployment, retrieve the jumphost information:

```bash
terraform output jumphost_details
```

Output example:
```json
{
  "access_instruction": "RDP to this jumphost, then access http://10.0.1.20 from the browser",
  "admin_username": "azureadmin",
  "name": "vme-kvm-jumphost",
  "private_ip": "10.0.1.100",
  "public_ip": "20.10.30.40",
  "rdp_command": "mstsc /v:20.10.30.40",
  "size": "Standard_B2s",
  "target_vm_ip": "10.0.1.20"
}
```

## Usage

### Connecting via RDP

#### From Windows
1. Open Remote Desktop Connection (mstsc.exe)
2. Enter the public IP address
3. Use credentials:
   - Username: `azureadmin` (or your configured username)
   - Password: Your configured password

Or use the command from output:
```bash
mstsc /v:<public_ip>
```

#### From macOS
1. Install Microsoft Remote Desktop from App Store
2. Create new connection with public IP
3. Enter credentials

#### From Linux
```bash
xfreerdp /u:azureadmin /v:<public_ip>
```

### Accessing Nested VM Web Application

Once connected to the jumphost:

1. Open a web browser (Edge, Chrome, Firefox)
2. Navigate to: `http://10.0.1.20`
3. Access your web application running on the nested VM

### Troubleshooting Connectivity

#### Test connectivity to nested VM:
```powershell
# From PowerShell on the jumphost
Test-NetConnection -ComputerName 10.0.1.20 -Port 80
```

#### Check routing:
```powershell
# Verify route to 10.0.1.16/28 via KVM host
Get-NetRoute -DestinationPrefix 10.0.1.16/28
```

#### Ping nested VM:
```powershell
ping 10.0.1.20
```

## Network Topology

The jumphost sits in the same subnet as the KVM host traffic interfaces, benefiting from the Azure Route Table that directs nested VM traffic:

```
Azure Route Table (applied to 10.0.1.0/24):
┌─────────────────────────────────────────┐
│ Route: 10.0.1.16/28  → 10.0.1.10       │  (vme-kvm-vm1)
│ Route: 10.0.1.48/28  → 10.0.1.11       │  (vme-kvm-vm2)
└─────────────────────────────────────────┘
         ↓                    ↓
   Windows Jumphost ──────> KVM Hosts
   (10.0.1.100)              (10.0.1.10/11)
                                  ↓
                            Nested VMs
                            (10.0.1.20, etc.)
```

## Outputs Reference

| Output | Description |
|--------|-------------|
| `jumphost_name` | Name of the Windows VM |
| `jumphost_public_ip` | Public IP for RDP access |
| `jumphost_private_ip` | Private IP in VM subnet |
| `jumphost_rdp_command` | Ready-to-use RDP command |
| `jumphost_details` | Complete jumphost information |

## Security Considerations

### Password Management
- Password is prompted at runtime and **never stored** in configuration files
- For automation, use environment variables:
  ```bash
  export TF_VAR_jumphost_admin_password="YourSecurePassword123!@#"
  terraform apply
  ```
- For production, use Azure Key Vault integration
- Rotate passwords regularly
- Consider using Azure AD authentication

### Network Security
- The NSG allows RDP from anywhere (`*`) - restrict this in production:
  ```hcl
  source_address_prefix = "YOUR_IP_ADDRESS/32"
  ```
- Consider using Azure Bastion for production jumphost access
- Enable Just-In-Time (JIT) VM access for additional security

### Monitoring
- Enable Azure Monitor for the jumphost
- Configure alerts for failed RDP login attempts
- Use Azure Security Center recommendations

## Cost Optimization

The default `Standard_B2s` VM size costs approximately:
- **~$35/month** (Pay-as-you-go pricing in East US)

To reduce costs:
1. Use auto-shutdown during non-business hours
2. Downgrade to `Standard_B1s` if performance allows
3. Deallocate when not in use (stops billing for compute)

```bash
# Stop (deallocate) the jumphost
az vm deallocate --resource-group rg-hpe-vme-test --name vme-kvm-jumphost

# Start when needed
az vm start --resource-group rg-hpe-vme-test --name vme-kvm-jumphost
```

## Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `jumphost_ip` | `10.0.1.100` | Static private IP in 10.0.1.0/24 |
| `jumphost_vm_size` | `Standard_B2s` | Azure VM size |
| `jumphost_admin_username` | `azureadmin` | Admin username |
| `jumphost_admin_password` | *required* | Admin password (sensitive) |

## Related Documentation

- [Main README](README.md) - Overall infrastructure documentation
- [NESTED-VM-NETWORKING.md](NESTED-VM-NETWORKING.md) - Nested VM networking details
- [Azure Route Tables Configuration](main.tf) - Routing configuration for nested VMs
