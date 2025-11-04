# HPE VM Essentials on Azure - KVM Host Setup

This project deploys a complete environment on Microsoft Azure for running KVM-based virtual machines, specifically tailored for nested virtualization scenarios. It sets up two KVM hosts, a Windows jumphost for management, and a VXLAN-based overlay network to allow seamless communication between nested VMs across different hosts.

## Architecture Overview

The infrastructure is defined using Terraform and configured with Ansible. Here is a high-level overview of the architecture:

### Core Infrastructure
- **Azure Resource Group**: A dedicated resource group to contain all project resources.
- **Virtual Network (VNet)**: A single VNet (`10.0.0.0/16`) with one subnet (`10.0.1.0/24`) for all VMs.
- **Private DNS Zone**: A private DNS zone (`hpevme.local`) is created and linked to the VNet, enabling name resolution for all resources within the VNet.

### Virtual Machines
- **KVM Hosts**: Two Ubuntu 24.04 VMs are deployed with nested virtualization enabled. These hosts are equipped with KVM, QEMU, and Open vSwitch to run and manage nested VMs.
- **Windows Jumphost**: A Windows Server 2022 VM is deployed to provide a graphical interface for managing and accessing nested VMs, especially those with web-based interfaces.

### Networking
- **VXLAN Overlay Network**: A VXLAN tunnel (VNI 10) is established between the KVM hosts, creating a layer 2 overlay network (`192.168.10.0/24`). This allows nested VMs on different hosts to communicate as if they were on the same local network.
- **OVS Bridge**: An Open vSwitch bridge named `mgmt` is created on each KVM host to connect the nested VMs to the overlay network.
- **Gateway and NAT**: One KVM host (`vme-kvm-vm1`) is designated as the gateway. It holds the gateway IP for the overlay network (`192.168.10.1`) and provides NAT services, allowing nested VMs to access the internet.
- **Azure User-Defined Routing (UDR)**: An Azure Route Table is used to direct all traffic destined for the overlay network (`192.168.10.0/24`) to the gateway KVM host. This provides centralized routing for the entire VNet.

### Security
- **Network Security Groups (NSGs)**: Access to the KVM hosts (SSH) and the jumphost (RDP, SSH) is restricted to your public IP address. All internal VNet traffic is allowed.
- **SSH Key Authentication**: The Linux KVM hosts are configured to only allow SSH key-based authentication.

## Getting Started

For a complete step-by-step guide on how to deploy and configure this environment, please refer to the [GETTING-STARTED.md](GETTING-STARTED.md) document.

## Detailed Documentation

This repository contains detailed documentation on various aspects of the infrastructure:

- **[NESTED-VM-NETWORKING.md](NESTED-VM-NETWORKING.md)**: A deep dive into the VXLAN overlay network, OVS bridge configuration, and how nested VMs communicate.
- **[AZURE-UDR-ROUTING.md](AZURE-UDR-ROUTING.md)**: Explains the role of Azure User-Defined Routes in this architecture.
- **[JUMPHOST.md](JUMPHOST.md)**: Provides details on the Windows jumphost, including how to connect to it and use it for management.
- **[CEPH-DISK-SETUP.md](CEPH-DISK-SETUP.md)**: Describes how to set up consistent disk naming using udev rules, which is a prerequisite for distributed storage solutions like Ceph.
- **[STATIC-IP-VERIFICATION.md](STATIC-IP-VERIFICATION.md)**: Explains the importance of static IP assignments in this architecture and how to verify them.
- **[TROUBLESHOOTING-INTERNET.md](TROUBLESHOOTING-INTERNET.md)**: Provides guidance on troubleshooting internet connectivity issues for nested VMs, including the MTU issue we resolved.

## Utility Playbooks

This project includes several Ansible playbooks to help you manage and verify the environment:

- **`playbook-deploy-test-vm.yml`**: Deploys a Fedora CoreOS VM on a KVM host for testing purposes. This is useful for quickly spinning up a nested VM to validate the overlay network and internet connectivity.
- **`playbook-destroy-test-vm.yml`**: Destroys the Fedora CoreOS test VM created by the deployment playbook.
- **`playbook-install-putty.yml`**: Installs the PuTTY SSH client on the Windows jumphost, providing an easy way to SSH into the KVM hosts from the jumphost.
- **`playbook-setup-consistent-disk-naming.yml`**: Configures udev rules on the KVM hosts to create stable, persistent symlinks for the attached data disks. This is essential for services like Ceph that require consistent device paths.
- **`playbook-verify-overlay.yml`**: A comprehensive playbook that runs a series of checks to verify that the VXLAN overlay network is configured correctly on all KVM hosts.

## Cleanup

To destroy all the resources created by this project, run the following command:

```bash
terraform destroy
```