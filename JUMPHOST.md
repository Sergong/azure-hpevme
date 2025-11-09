# Windows Jumphost Configuration

## Overview

A Windows Server 2022 jumphost VM is included in the infrastructure to provide a graphical interface for managing and accessing the KVM hosts and nested VMs. It is deployed in the same subnet as the KVM hosts, allowing for seamless connectivity.

## Configuration

### IP Addressing
- **Private IP**: `10.0.1.200` (static)
- **Subnet**: `10.0.1.0/24`

### VM Specifications
- **OS**: Windows Server 2022 Datacenter
- **Size**: `Standard_B2s` (configurable in `terraform.tfvars`)
- **Admin Username**: `azureadmin` (configurable)
- **Admin Password**: Set at deployment time.

### Network Connectivity

The jumphost is in the same subnet as the KVM hosts and benefits from the Azure User-Defined Route (UDR). This means it can directly access the nested VMs on the overlay network (`192.168.10.0/24`) without any special configuration.

## Deployment

The jumphost is deployed as part of the main `terraform apply` command. You will be prompted to enter a password for the administrator account during the deployment.

## Usage

### Connecting via RDP

1.  **Get the public IP address** of the jumphost from the Terraform output:
    ```bash
    terraform output jumphost_public_ip
    ```

2.  **Connect using your preferred RDP client**. The username is `azureadmin` (or as configured) and the password is the one you provided during deployment.

### Accessing KVM Hosts and Nested VMs

Once connected to the jumphost, you can:

-   **SSH to the KVM hosts**: The `playbook-install-putty.yml` playbook installs the PuTTY SSH client for this purpose.
-   **Access nested VM web interfaces**: Open a web browser on the jumphost and navigate to the IP address of your nested VM (e.g., `http://192.168.10.30`).

## Security

-   **RDP and SSH access** to the jumphost is restricted to your public IP address by the Network Security Group.
-   For production environments, consider using **Azure Bastion** for more secure access.