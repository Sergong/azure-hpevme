# Nested VM Networking with VXLAN Overlay

## Overview

This document describes the networking architecture that enables communication for nested VMs running on the KVM hosts. The architecture is based on a VXLAN overlay network, which creates a virtual Layer 2 network on top of the underlying Azure VNet. This allows nested VMs on different KVM hosts to communicate as if they were on the same physical network segment.

## Core Components

### 1. VXLAN Overlay Network
- **Technology**: VXLAN (Virtual Extensible LAN) is used to create a virtual overlay network.
- **VNI (VXLAN Network Identifier)**: The overlay network is identified by VNI `10`.
- **IP Range**: The overlay network uses the `192.168.10.0/24` IP address range.
- **Transport**: VXLAN encapsulates Layer 2 frames in UDP packets, allowing them to traverse the underlying Layer 3 network (the Azure VNet).

### 2. Open vSwitch (OVS) Bridge
- **Bridge Name**: An OVS bridge named `mgmt` is created on each KVM host.
- **Purpose**: The `mgmt` bridge acts as a virtual switch for the nested VMs. All nested VMs are connected to this bridge.
- **VXLAN Port**: The VXLAN tunnel interface (`vxlan0`) is a port on the `mgmt` bridge, connecting it to the overlay network.

### 3. Gateway Host
- **Designation**: The first KVM host (`vme-kvm-vm1`) is designated as the gateway for the overlay network.
- **Gateway IP**: The `mgmt` bridge on the gateway host is assigned the IP address `192.168.10.1`, which serves as the default gateway for all nested VMs.
- **NAT (Network Address Translation)**: The gateway host is configured with `iptables` rules to perform NAT for all traffic originating from the overlay network. This allows nested VMs to access the internet.

### 4. Azure User-Defined Routing (UDR)
- **Purpose**: An Azure Route Table is used to direct all traffic from the Azure VNet that is destined for the overlay network (`192.168.10.0/24`) to the gateway host (`10.0.1.4`).
- **Centralized Routing**: This provides a centralized routing solution, eliminating the need for manual route configuration on individual VMs in the VNet.

## Traffic Flow Examples

### Guest-to-Guest (Same Host)
1.  A nested VM sends a packet to another nested VM on the same KVM host.
2.  The packet travels through the `mgmt` bridge.
3.  The `mgmt` bridge, acting as a Layer 2 switch, forwards the packet directly to the destination VM.

### Guest-to-Guest (Cross-Host)
1.  A nested VM on `vme-kvm-vm2` sends a packet to a nested VM on `vme-kvm-vm1`.
2.  The packet goes to the `mgmt` bridge on `vme-kvm-vm2`.
3.  The bridge forwards the packet to the `vxlan0` port.
4.  The VXLAN tunnel encapsulates the packet in a UDP datagram and sends it to the gateway host (`vme-kvm-vm1`) over the Azure VNet.
5.  The gateway host receives the VXLAN packet, decapsulates it, and forwards it to its `mgmt` bridge.
6.  The `mgmt` bridge delivers the packet to the destination VM.

### Guest-to-Internet
1.  A nested VM sends a packet to an external address (e.g., `8.8.8.8`).
2.  The packet is sent to its default gateway, which is the `mgmt` bridge on the gateway host (`192.168.10.1`).
3.  The gateway host receives the packet on its `mgmt` bridge.
4.  The `iptables` NAT rule on the gateway host masquerades the packet, changing its source IP address to the IP address of the host's `eth0` interface.
5.  The packet is then sent out to the internet through the Azure VNet.

## Configuration Details

The entire network configuration is managed by `netplan` on the KVM hosts, ensuring that the settings are persistent across reboots. The configuration is defined in `/etc/netplan/99-ovs.yaml` and is generated from the `netplan-with-ovs.yaml.j2` template in this repository.

For more information on the specific `netplan` configuration, please refer to the `netplan-with-ovs.yaml.j2` file.