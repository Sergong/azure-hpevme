# Architecture Summary: VXLAN Overlay Network

## Overview

This document provides a high-level summary of the VXLAN-based overlay network architecture used in this project.

## Core Components

-   **VXLAN Overlay Network**: A virtual Layer 2 network (`192.168.10.0/24`) is created using VXLAN (VNI 10). This allows nested VMs on different KVM hosts to communicate as if they were on the same local network.

-   **Open vSwitch (OVS)**: An OVS bridge named `mgmt` is used on each KVM host to connect nested VMs to the overlay network.

-   **Gateway and NAT**: One KVM host (`vme-kvm-vm1`) acts as the gateway for the overlay network, providing a default route (`192.168.10.1`) and NAT services for internet access.

-   **Azure User-Defined Routing (UDR)**: A single Azure Route Table directs all traffic from the VNet destined for the overlay network to the gateway host. This centralizes routing and simplifies host configuration.

## Traffic Flow

-   **East-West (Guest-to-Guest)**: Communication between nested VMs on different hosts is encapsulated in VXLAN and routed over the Azure VNet.

-   **North-South (Guest-to-Internet)**: Traffic from nested VMs to the internet is routed to the gateway host, which performs NAT.

-   **VNet to Overlay**: Traffic from any resource in the VNet (e.g., the Windows jumphost) to the overlay network is directed to the gateway host by the Azure UDR.

## Key Benefits

-   **Seamless Connectivity**: Nested VMs can communicate with each other, with the KVM hosts, and with other resources in the VNet.
-   **Internet Access**: Nested VMs have internet access via NAT on the gateway host.
-   **Centralized Management**: Routing for the overlay network is managed centrally in Azure, simplifying the configuration of individual hosts.
-   **Persistence**: The entire network configuration is defined in `netplan` and is persistent across reboots.