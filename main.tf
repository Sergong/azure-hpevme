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

# Route Table for nested VMs
resource "azurerm_route_table" "nested_vm_routes" {
  name                = "${var.prefix}-nested-vm-routes"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Routes for nested VMs - direct traffic to respective KVM hosts
resource "azurerm_route" "nested_vm_route" {
  count                  = var.vm_count
  name                   = "${var.prefix}-nested-vm${count.index + 1}-route"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.nested_vm_routes.name
  address_prefix         = var.nested_vm_ip_ranges[count.index]
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = var.vm_traffic_ips[count.index]
}

# VM Traffic Subnet
resource "azurerm_subnet" "vm_subnet" {
  name                 = "${var.prefix}-vm-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Associate route table with VM traffic subnet
resource "azurerm_subnet_route_table_association" "vm_subnet_routes" {
  subnet_id      = azurerm_subnet.vm_subnet.id
  route_table_id = azurerm_route_table.nested_vm_routes.id
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
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ICMP"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
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
  enable_ip_forwarding = true

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
  enable_ip_forwarding = true

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

              # Update package lists with new repositories
              apt update
              apt upgrade -y
              apt install -y curl wget git vim htop tree
              
              # Format and mount the data disk (1TB)
              # Wait for the disk to be available
              sleep 30
              
              # Find the data disk (usually /dev/sdc for the first data disk)
              DATA_DISK=$(lsblk -f | grep -E '^sd[b-z]' | grep -v 'part' | head -1 | awk '{print "/dev/" $1}')
              if [ -n "$DATA_DISK" ]; then
                  # Create partition
                  parted $DATA_DISK mklabel gpt
                  parted $DATA_DISK mkpart primary ext4 0% 100%
                  
                  # Format with ext4
                  mkfs.ext4 $${DATA_DISK}1
                  
                  # Create mount point
                  mkdir -p /data
                  
                  # Get UUID of the partition
                  UUID=$(blkid -s UUID -o value $${DATA_DISK}1)
                  
                  # Add to fstab for persistent mounting
                  echo "UUID=$UUID /data ext4 defaults,nofail 0 2" >> /etc/fstab
                  
                  # Mount the disk
                  mount /data
                  
                  # Set permissions
                  chown root:root /data
                  chmod 755 /data
                  
                  # Create a readme file
                  echo "This is a 1TB data disk mounted at /data" > /data/README.txt
                  echo "Disk mounted successfully at /data with UUID: $UUID" >> /var/log/disk-setup.log
              else
                  echo "No additional disk found" >> /var/log/disk-setup.log
              fi
              
              # Create a welcome message
              echo "Welcome to Ubuntu 24.04 VM${count.index + 1}" > /etc/motd
              echo "Data disk (1TB) available at /data" >> /etc/motd
              EOF
  )

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
