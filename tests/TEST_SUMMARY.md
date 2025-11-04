# Unit Test Suite - Summary

## Overview

A comprehensive unit test suite has been created to validate the Azure KVM VXLAN overlay infrastructure across all components.

## Test Files

### 1. Azure Infrastructure (OpenTofu)

- **`route_tables.tftest.hcl`**: Tests the Azure Route Table and User-Defined Route (UDR) for the VXLAN overlay network.
- **`ip_forwarding.tftest.hcl`**: Tests that IP forwarding is enabled on the network interfaces of the KVM hosts.

### 2. KVM Host Configuration (Ansible)

- **`tests/ansible/test_ovs_bridge.yml`**: Tests the `netplan` configuration for the OVS bridge and VXLAN tunnel.
- **`tests/ansible/test_nat_config.yml`**: Tests the NAT configuration on the gateway KVM host.
- **`tests/ansible/test_iptables_persistent.yml`**: Tests the installation of `iptables-persistent` and the saving of `iptables` rules.

### 3. NAT Script (BATS)

- **`tests/bash/test_setup_nat.bats`**: Tests the `setup-nested-vm-nat.sh` script.

## Test Statistics

| Test Category | Test Files |
|--------------|------------|
| OpenTofu     | 2          |
| Ansible      | 3          |
| Bash/BATS    | 1          |
| **TOTAL**    | **6**      |

## Quick Start

### Run All Tests

```bash
./tests/run_all_tests.sh
```
