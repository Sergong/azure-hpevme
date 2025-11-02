terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "main" {
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = "${var.prefix}-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = true

  tags = var.tags
}

# DNS A Records for Linux VMs (management IPs)
resource "azurerm_private_dns_a_record" "vm" {
  count               = var.vm_count
  name                = "${var.prefix}-vm${count.index + 1}"
  zone_name           = azurerm_private_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_network_interface.management_nic[count.index].private_ip_address]

  tags = var.tags
}

# DNS A Records for Linux VMs (traffic IPs)
resource "azurerm_private_dns_a_record" "vm_traffic" {
  count               = var.vm_count
  name                = "${var.prefix}-vm${count.index + 1}-traffic"
  zone_name           = azurerm_private_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [var.vm_traffic_ips[count.index]]

  tags = var.tags
}

# DNS A Record for Windows Jumphost
resource "azurerm_private_dns_a_record" "jumphost" {
  name                = "jumphost"
  zone_name           = azurerm_private_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [var.jumphost_ip]

  tags = var.tags
}

# DNS A Record for HPE VME nested VM
resource "azurerm_private_dns_a_record" "hpevme" {
  name                = "hpevme"
  zone_name           = azurerm_private_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["10.0.1.20"]

  tags = var.tags
}

# Reverse DNS Zone for 10.0.1.0/24 (VM traffic subnet)
resource "azurerm_private_dns_zone" "reverse_vm_traffic" {
  name                = "1.0.10.in-addr.arpa"
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Link Reverse DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "reverse_vm_traffic_link" {
  name                  = "${var.prefix}-reverse-vm-traffic-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.reverse_vm_traffic.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}

# Reverse DNS Zone for 10.0.2.0/24 (management subnet)
resource "azurerm_private_dns_zone" "reverse_management" {
  name                = "2.0.10.in-addr.arpa"
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Link Reverse DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "reverse_management_link" {
  name                  = "${var.prefix}-reverse-management-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.reverse_management.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}

# PTR Records for Linux VMs (management IPs)
resource "azurerm_private_dns_ptr_record" "vm_management" {
  count               = var.vm_count
  name                = element(split(".", azurerm_network_interface.management_nic[count.index].private_ip_address), 3)
  zone_name           = azurerm_private_dns_zone.reverse_management.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["${var.prefix}-vm${count.index + 1}.${azurerm_private_dns_zone.main.name}"]

  tags = var.tags
}

# PTR Records for Linux VMs (traffic IPs)
resource "azurerm_private_dns_ptr_record" "vm_traffic" {
  count               = var.vm_count
  name                = element(split(".", var.vm_traffic_ips[count.index]), 3)
  zone_name           = azurerm_private_dns_zone.reverse_vm_traffic.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["${var.prefix}-vm${count.index + 1}-traffic.${azurerm_private_dns_zone.main.name}"]

  tags = var.tags
}

# PTR Record for Windows Jumphost
resource "azurerm_private_dns_ptr_record" "jumphost" {
  name                = element(split(".", var.jumphost_ip), 3)
  zone_name           = azurerm_private_dns_zone.reverse_management.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["jumphost.${azurerm_private_dns_zone.main.name}"]

  tags = var.tags
}

# VM Traffic Subnet
resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.prefix}-vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}




# Management Traffic Subnet
resource "azurerm_subnet" "management_subnet" {
  name                 = "${var.prefix}-management-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}



# Network Security Group
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "${var.prefix}-vm-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_public_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGRE"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowNestedVMSubnet"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowVnetOutbound"
    priority                   = 1006
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }


  tags = var.tags
}

# Public IPs
resource "azurerm_public_ip" "vm_public_ip" {
  count               = var.vm_count
  name                = "${var.prefix}-vm${count.index + 1}-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# VM Traffic Network Interfaces
resource "azurerm_network_interface" "vm_nic" {
  count                = var.vm_count
  name                 = "${var.prefix}-vm${count.index + 1}-vm-nic"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "vm-traffic"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm_traffic_ips[count.index]
  }

  tags = var.tags
}

# Management Network Interfaces
resource "azurerm_network_interface" "management_nic" {
  count                = var.vm_count
  name                 = "${var.prefix}-vm${count.index + 1}-management-nic"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "management-traffic"
    subnet_id                     = azurerm_subnet.management_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip[count.index].id
  }

  tags = var.tags
}

# Associate Network Security Group to VM Traffic Network Interface
resource "azurerm_network_interface_security_group_association" "vm_nsg_association" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.vm_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Associate Network Security Group to Management Network Interface
resource "azurerm_network_interface_security_group_association" "management_nsg_association" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.management_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# SSH Key
resource "azurerm_ssh_public_key" "vm_ssh_key" {
  name                = "${var.prefix}-ssh-key"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  public_key          = file(var.ssh_public_key_path)

  tags = var.tags
}

# Data Disks (1TB each)
resource "azurerm_managed_disk" "data_disk" {
  count                = var.vm_count
  name                 = "${var.prefix}-vm${count.index + 1}-data-disk"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 1024

  tags = var.tags
}

# Virtual Machines
resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "${var.prefix}-vm${count.index + 1}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Disable password authentication
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.management_nic[count.index].id,
    azurerm_network_interface.vm_nic[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = azurerm_ssh_public_key.vm_ssh_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Cloud-init script to update packages, install tools, setup HPE repos, and setup data disk
  custom_data = base64encode(<<-EOF
              #!/bin/bash
              set -e  # Exit on error, but we'll handle disk setup separately
              
              # Log function
              log() {
                  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a /var/log/disk-setup.log
              }

              # Update package lists with new repositories
              log "Starting system update"
              apt update
              apt upgrade -y
              apt install -y curl wget git vim htop tree parted
              log "System update completed"
              
              # Format and mount the data disk (1TB) using LUN-based detection
              # This section uses 'set +e' to handle errors gracefully
              set +e
              
              log "Starting data disk setup"
              
              # Wait for the disk to be available
              log "Waiting for disk to be available"
              sleep 30
              
              # Find the data disk by LUN (attached at LUN 10)
              DATA_DISK=""
              if [ -L "/dev/disk/azure/scsi1/lun10" ]; then
                  DATA_DISK=$(readlink -f /dev/disk/azure/scsi1/lun10)
                  log "Found data disk at LUN 10: $DATA_DISK"
              else
                  log "LUN 10 symlink not found, trying fallback detection"
                  # Fallback: find disk by size (1TB = ~1024GB)
                  DATA_DISK=$(lsblk -ndo NAME,SIZE | grep -E '1(\.0)?T' | head -1 | awk '{print "/dev/" $1}')
                  if [ -n "$DATA_DISK" ]; then
                      log "Found data disk by size: $DATA_DISK"
                  fi
              fi
              
              if [ -z "$DATA_DISK" ] || [ ! -b "$DATA_DISK" ]; then
                  log "ERROR: No data disk found at LUN 10 or by size"
                  exit 0  # Don't fail cloud-init
              fi
              
              # Determine partition name
              PARTITION="$${DATA_DISK}1"
              [[ $DATA_DISK == *"nvme"* ]] && PARTITION="$${DATA_DISK}p1"
              
              # Check if partition already exists
              if [ -b "$PARTITION" ]; then
                  log "Partition $PARTITION already exists, checking filesystem"
                  if blkid "$PARTITION" | grep -q "TYPE=\"ext4\""; then
                      log "Filesystem already exists on $PARTITION"
                  else
                      log "No filesystem found, formatting $PARTITION"
                      mkfs.ext4 -F "$PARTITION" 2>&1 | tee -a /var/log/disk-setup.log
                  fi
              else
                  log "Creating partition on $DATA_DISK"
                  parted -s "$DATA_DISK" mklabel gpt 2>&1 | tee -a /var/log/disk-setup.log
                  parted -s "$DATA_DISK" mkpart primary ext4 0% 100% 2>&1 | tee -a /var/log/disk-setup.log
                  sleep 5
                  
                  # Wait for partition to appear
                  for i in {1..10}; do
                      if [ -b "$PARTITION" ]; then
                          log "Partition $PARTITION is now available"
                          break
                      fi
                      log "Waiting for partition to appear (attempt $i/10)"
                      sleep 2
                  done
                  
                  if [ ! -b "$PARTITION" ]; then
                      log "ERROR: Partition $PARTITION did not appear after waiting"
                      exit 0
                  fi
                  
                  log "Formatting $PARTITION with ext4"
                  mkfs.ext4 -F "$PARTITION" 2>&1 | tee -a /var/log/disk-setup.log
              fi
              
              # Create mount point if it doesn't exist
              if [ ! -d "/data" ]; then
                  log "Creating /data directory"
                  mkdir -p /data
              fi
              
              # Get UUID of the partition
              UUID=$(blkid -s UUID -o value "$PARTITION")
              if [ -z "$UUID" ]; then
                  log "ERROR: Could not get UUID for $PARTITION"
                  exit 0
              fi
              log "Partition UUID: $UUID"
              
              # Check if already in fstab
              if ! grep -q "/data" /etc/fstab; then
                  log "Adding $PARTITION to /etc/fstab"
                  echo "UUID=$UUID /data ext4 defaults,nofail 0 2" >> /etc/fstab
              else
                  log "/data already in /etc/fstab"
              fi
              
              # Mount the disk if not already mounted
              if ! mountpoint -q /data; then
                  log "Mounting /data"
                  mount /data 2>&1 | tee -a /var/log/disk-setup.log
                  if [ $? -eq 0 ]; then
                      log "Successfully mounted /data"
                  else
                      log "ERROR: Failed to mount /data"
                      exit 0
                  fi
              else
                  log "/data is already mounted"
              fi
              
              # Set permissions
              chown root:root /data
              chmod 755 /data
              
              # Create a readme file
              if [ ! -f /data/README.txt ]; then
                  echo "This is a 1TB data disk mounted at /data" > /data/README.txt
                  log "Created README.txt"
              fi
              
              log "Data disk setup completed successfully (UUID: $UUID, Device: $PARTITION)"
              
              # Create a welcome message
              echo "Welcome to Ubuntu 24.04 VM${count.index + 1}" > /etc/motd
              echo "Data disk (1TB) available at /data" >> /etc/motd
              
              # Configure DNS search domain for private DNS zone via netplan
              log "Configuring DNS search domain"
              
              # Wait for cloud-init network config to complete
              sleep 10
              
              # Add DNS search domain to netplan config
              cat > /etc/netplan/99-private-dns.yaml <<'DNS_EOF'
network:
  version: 2
  ethernets:
    eth0:
      nameservers:
        search: [hpevme.local, 5q1ivbogeb3eblqguatgczs0gh.bx.internal.cloudapp.net]
      dhcp4-overrides:
        use-dns: true
DNS_EOF
              
              chmod 600 /etc/netplan/99-private-dns.yaml
              netplan apply
              log "DNS configuration completed"
              
              log "Cloud-init script completed"
              EOF
  )

  lifecycle {
    ignore_changes = [custom_data]
  }

  tags = var.tags
}

# Attach Data Disks to VMs
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  count              = var.vm_count
  managed_disk_id    = azurerm_managed_disk.data_disk[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[count.index].id
  lun                = "10"
  caching            = "ReadWrite"
}

# Windows Jumphost Resources
# Network Security Group for Windows Jumphost
resource "azurerm_network_security_group" "jumphost_nsg" {
  name                = "${var.prefix}-jumphost-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.my_public_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_public_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowVnetOutbound"
    priority                   = 1004
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = var.tags
}

# Public IP for Windows Jumphost
resource "azurerm_public_ip" "jumphost_public_ip" {
  name                = "${var.prefix}-jumphost-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Network Interface for Windows Jumphost
resource "azurerm_network_interface" "jumphost_nic" {
  name                = "${var.prefix}-jumphost-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "jumphost-config"
    subnet_id                     = azurerm_subnet.management_subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.jumphost_ip
    public_ip_address_id          = azurerm_public_ip.jumphost_public_ip.id
  }

  tags = var.tags
}

# Associate NSG to Jumphost NIC
resource "azurerm_network_interface_security_group_association" "jumphost_nsg_association" {
  network_interface_id      = azurerm_network_interface.jumphost_nic.id
  network_security_group_id = azurerm_network_security_group.jumphost_nsg.id
}

# Windows Jumphost VM
resource "azurerm_windows_virtual_machine" "jumphost" {
  name                = "${var.prefix}-jumphost"
  computer_name       = "${var.prefix}-jump"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.jumphost_vm_size
  admin_username      = var.jumphost_admin_username
  admin_password      = var.jumphost_admin_password

  network_interface_ids = [
    azurerm_network_interface.jumphost_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  # Enable automatic updates
  enable_automatic_updates = true
  patch_mode               = "AutomaticByOS"

  # Install OpenSSH Server for Ansible management
  custom_data = base64encode(<<-EOF
    <powershell>
    # Enable logging
    Start-Transcript -Path C:\Windows\Temp\openssh-setup.log -Append
    
    Write-Host "Installing OpenSSH Server..."
    
    # Install OpenSSH Server capability
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    
    # Start the sshd service
    Start-Service sshd
    
    # Set sshd service to start automatically
    Set-Service -Name sshd -StartupType 'Automatic'
    
    # Confirm the Firewall rule is configured (should be created automatically)
    if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        Write-Host "Creating firewall rule for OpenSSH Server..."
        New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    } else {
        Write-Host "Firewall rule for OpenSSH Server already exists"
    }
    
    # Configure OpenSSH to use password authentication
    $sshdConfigPath = "C:\ProgramData\ssh\sshd_config"
    if (Test-Path $sshdConfigPath) {
        Write-Host "Configuring sshd_config for password authentication..."
        $config = Get-Content $sshdConfigPath
        $config = $config -replace '^#?PasswordAuthentication.*', 'PasswordAuthentication yes'
        $config = $config -replace '^#?PubkeyAuthentication.*', 'PubkeyAuthentication yes'
        $config | Set-Content $sshdConfigPath
        
        # Restart sshd to apply changes
        Restart-Service sshd
    }
    
    # Configure default shell to PowerShell (optional, for better Ansible compatibility)
    New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force
    
    Write-Host "Configuring DNS suffix search list..."
    # Add hpevme.local to DNS suffix search list
    Set-DnsClientGlobalSetting -SuffixSearchList @("hpevme.local","5q1ivbogeb3eblqguatgczs0gh.bx.internal.cloudapp.net")
    
    # Flush DNS cache
    Clear-DnsClientCache
    ipconfig /flushdns
    
    Write-Host "Configuring Windows Firewall for ICMP..."
    # Enable ICMP Echo Request for all network profiles
    Set-NetFirewallRule -DisplayName 'File and Printer Sharing (Echo Request - ICMPv4-In)' -Enabled True -Profile Any
    
    Write-Host "OpenSSH Server installation, DNS, and firewall configuration completed"
    
    Stop-Transcript
    </powershell>
    EOF
  )

  lifecycle {
    ignore_changes = [custom_data]
  }

  tags = merge(var.tags, {
    Role = "Jumphost"
  })
}
