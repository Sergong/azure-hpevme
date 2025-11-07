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

# DNS A Records for Linux VMs
resource "azurerm_private_dns_a_record" "vm" {
  count               = var.vm_count
  name                = "${var.prefix}-vm${count.index + 1}"
  zone_name           = azurerm_private_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_network_interface.vm_nic[count.index].private_ip_address]

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

# DNS A Record for example nested VM (in overlay network)
resource "azurerm_private_dns_a_record" "hpevme" {
  name                = "hpevme"
  zone_name           = azurerm_private_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["192.168.10.20"]

  tags = var.tags
}

# Reverse DNS Zone for 10.0.1.0/24 (VM subnet)
resource "azurerm_private_dns_zone" "reverse_vm" {
  name                = "1.0.10.in-addr.arpa"
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Link Reverse DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "reverse_vm_link" {
  name                  = "${var.prefix}-reverse-vm-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.reverse_vm.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false

  tags = var.tags
}

# PTR Records for Linux VMs
resource "azurerm_private_dns_ptr_record" "vm" {
  count               = var.vm_count
  name                = element(split(".", azurerm_network_interface.vm_nic[count.index].private_ip_address), 3)
  zone_name           = azurerm_private_dns_zone.reverse_vm.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["${var.prefix}-vm${count.index + 1}.${azurerm_private_dns_zone.main.name}"]

  tags = var.tags
}

# PTR Record for Windows Jumphost
resource "azurerm_private_dns_ptr_record" "jumphost" {
  name                = element(split(".", var.jumphost_ip), 3)
  zone_name           = azurerm_private_dns_zone.reverse_vm.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = ["jumphost.${azurerm_private_dns_zone.main.name}"]

  tags = var.tags
}

# VM Subnet (single subnet for all VMs)
resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.prefix}-vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# VM Subnet 2 (for second NIC)
resource "azurerm_subnet" "vm_subnet_2" {
  name                 = "${var.prefix}-vm-subnet-2"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Route Table for overlay network routing
# IMPORTANT: This route table directs overlay network traffic (192.168.10.0/24) to the gateway host.
# The next_hop_ip_address MUST match vm_ips[0] which is statically assigned to vme-kvm-vm1.
resource "azurerm_route_table" "overlay_routes" {
  name                = "${var.prefix}-overlay-routes"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Route overlay network traffic to gateway host (first KVM host)
  route {
    name                   = "overlay-network-to-gateway"
    address_prefix         = "192.168.10.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.vm_ips[0]  # Must be 10.0.1.4 (validated in variables.tf)
  }

  tags = var.tags
}

# Route Table for the second subnet (no custom routes)
resource "azurerm_route_table" "no_routes" {
  name                = "${var.prefix}-no-routes"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Associate route table with VM subnet
resource "azurerm_subnet_route_table_association" "vm_subnet_routes" {
  subnet_id      = azurerm_subnet.vm_subnet.id
  route_table_id = azurerm_route_table.overlay_routes.id
}

# Associate no-routes table with second VM subnet
resource "azurerm_subnet_route_table_association" "vm_subnet_2_no_routes" {
  subnet_id      = azurerm_subnet.vm_subnet_2.id
  route_table_id = azurerm_route_table.no_routes.id
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

# VM Network Interfaces (single NIC per VM with public IP)
# IMPORTANT: Static IP assignment is REQUIRED. vm_ips[0] = 10.0.1.4 is used in Azure UDR.
resource "azurerm_network_interface" "vm_nic" {
  count                 = var.vm_count
  name                  = "${var.prefix}-vm${count.index + 1}-nic"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  ip_forwarding_enabled = true  # Required for gateway host to route overlay traffic

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    private_ip_address_allocation = "Static"  # MUST be Static - Dynamic IPs would break overlay routing
    private_ip_address            = var.vm_ips[count.index]  # vm1=10.0.1.4 (gateway), vm2=10.0.1.5
    public_ip_address_id          = azurerm_public_ip.vm_public_ip[count.index].id
  }

  tags = var.tags
}

# VM Network Interfaces 2 (second NIC per VM)
resource "azurerm_network_interface" "vm_nic_2" {
  count                 = var.vm_count
  name                  = "${var.prefix}-vm${count.index + 1}-nic-2"
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "secondary"
    subnet_id                     = azurerm_subnet.vm_subnet_2.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.vm_ips_2[count.index]
  }

  tags = var.tags
}

# Associate Network Security Group to VM Network Interface
resource "azurerm_network_interface_security_group_association" "vm_nsg_association" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.vm_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

# Associate Network Security Group to second VM Network Interface
resource "azurerm_network_interface_security_group_association" "vm_nsg_association_2" {
  count                     = var.vm_count
  network_interface_id      = azurerm_network_interface.vm_nic_2[count.index].id
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
    azurerm_network_interface.vm_nic[count.index].id,
    azurerm_network_interface.vm_nic_2[count.index].id,
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
              log "Configuring DNS search domain and overlay network support"
              
              # Wait for cloud-init network config to complete
              sleep 10
              
              # Add DNS search domain to netplan config
              # Note: This is initial config; Ansible will reconfigure with static IPs later
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
              
              # Enable IP forwarding for nested VMs and overlay network
              log "Enabling IP forwarding"
              sysctl -w net.ipv4.ip_forward=1
              echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
              log "IP forwarding enabled"
              
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
    subnet_id                     = azurerm_subnet.vm_subnet.id
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

  tags = merge(var.tags, {
    Role = "Jumphost"
  })
}

# Storage account for scripts
resource "azurerm_storage_account" "scripts" {
  name                     = "${replace(var.prefix, "-", "")}scripts${substr(md5(azurerm_resource_group.main.id), 0, 6)}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_name  = azurerm_storage_account.scripts.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "openssh_script" {
  name                   = "setup-openssh.ps1"
  storage_account_name   = azurerm_storage_account.scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source                 = "${path.module}/scripts/setup-openssh.ps1"
}

# Windows VM Extension to install and configure OpenSSH Server
resource "azurerm_virtual_machine_extension" "jumphost_openssh" {
  name                 = "install-openssh"
  virtual_machine_id   = azurerm_windows_virtual_machine.jumphost.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    fileUris = [azurerm_storage_blob.openssh_script.url]
  })

  protected_settings = jsonencode({
    commandToExecute = var.openssh_extension_update_tag != null ? "powershell.exe -ExecutionPolicy Unrestricted -File setup-openssh.ps1 ${var.openssh_extension_update_tag}" : "powershell.exe -ExecutionPolicy Unrestricted -File setup-openssh.ps1"
  })

  tags = var.tags
}
