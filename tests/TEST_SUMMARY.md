# Unit Test Suite - Summary

## Overview

A comprehensive unit test suite has been created to validate the Azure KVM nested VM networking infrastructure across all components.

## Test Files Created

### 1. Terraform Tests

#### `tests/terraform/route_tables.tftest.hcl`
**Tests:** Azure Route Tables Configuration (Test Case 1)

**Coverage:**
- ✅ Route table creation with correct naming
- ✅ Route count matches VM count
- ✅ Route address prefixes (10.0.1.16/28, 10.0.1.48/28, etc.)
- ✅ Next hop type is VirtualAppliance
- ✅ Next hop IP addresses point to correct KVM hosts
- ✅ Route table subnet association
- ✅ Multiple host configurations (2-10 VMs)

**Test Runs:** 6 test scenarios with multiple assertions

#### `tests/terraform/ip_forwarding.tftest.hcl`
**Tests:** IP Forwarding Configuration (Test Case 2)

**Coverage:**
- ✅ IP forwarding enabled on VM traffic NICs
- ✅ IP forwarding enabled on management NICs
- ✅ All NICs have IP forwarding across all VM counts
- ✅ Static IP configuration validation
- ✅ IP configuration naming (vm-traffic)
- ✅ Comprehensive validation for 1-10 VMs

**Test Runs:** 5 test scenarios with multiple assertions

### 2. Bash/BATS Tests

#### `tests/bash/test_setup_routes.bats`
**Tests:** setup-nested-vm-routes.sh Script (Test Case 3)

**Coverage:**
- ✅ Host IP extraction from mgmt bridge interface
- ✅ Route entry parsing (CIDR:IP format)
- ✅ Skipping routes for own IP range
- ✅ Adding routes for other hosts
- ✅ Detecting existing routes before adding
- ✅ Creating persistent systemd network configuration
- ✅ Correct [Route] section format
- ✅ Multiple route entry handling
- ✅ CIDR notation validation
- ✅ IP address format validation
- ✅ Configuration file path verification
- ✅ Network device name validation (mgmt)

**Test Runs:** 15 individual BATS test cases

### 3. Ansible Tests

#### `tests/ansible/test_ovs_bridge.yml`
**Tests:** OVS Bridge Configuration (Test Case 4)

**Coverage:**
- ✅ OVS bridge existence check command
- ✅ IP address extraction from eth1 using regex
- ✅ Bridge creation command (ovs-vsctl add-br mgmt)
- ✅ Port addition to bridge (eth1 → mgmt)
- ✅ IP assignment to mgmt bridge
- ✅ IP flushing from eth1
- ✅ Bridge bring-up command
- ✅ Netplan configuration update (eth1 → mgmt)
- ✅ Netplan apply command
- ✅ Conditional task execution logic
- ✅ Bridge name consistency across tasks
- ✅ Interface name validation (eth1)
- ✅ IP address preservation during migration
- ✅ Changed_when condition for routes
- ✅ All OVS tasks have proper conditionals

**Test Runs:** 15 assertion-based tests

#### `tests/ansible/test_iptables_persistent.yml`
**Tests:** iptables-persistent Configuration (Test Case 5)

**Coverage:**
- ✅ iptables-persistent package inclusion
- ✅ netfilter-persistent package inclusion
- ✅ UFW exclusion (incompatible with iptables-persistent)
- ✅ netfilter-persistent save command
- ✅ NAT script configuration
- ✅ Rule persistence after NAT setup
- ✅ changed_when set to false for save command
- ✅ Libvirt chains preserved with iptables-persistent
- ✅ NAT MASQUERADE rule for internet access
- ✅ iptables FORWARD rules for nested VMs
- ✅ Interface name consistency (eth0, mgmt)
- ✅ Firewall configured via bash scripts
- ✅ Task execution order in playbook
- ✅ netfilter-persistent save uses command module
- ✅ All nested VM networking requirements met

**Test Runs:** 15 assertion-based tests

## Test Statistics

| Test Category | Test Files | Test Scenarios/Cases | Assertions |
|--------------|------------|---------------------|------------|
| Terraform    | 2          | 11                  | 30+        |
| Bash/BATS    | 1          | 15                  | 15         |
| Ansible      | 2          | 30                  | 60+        |
| **TOTAL**    | **5**      | **56**              | **105+**   |

## Quick Start

### Run All Tests
```bash
./tests/run_all_tests.sh
```

### Run Individual Test Suites

**Terraform:**
```bash
cd tests/terraform
terraform test
```

**BATS:**
```bash
cd tests/bash
bats test_setup_routes.bats
```

**Ansible:**
```bash
cd tests/ansible
ansible-playbook test_ovs_bridge.yml test_iptables_persistent.yml
```

## Test Coverage Map

```
┌─────────────────────────────────────────────────────────────┐
│                   Azure Infrastructure                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │ Azure Route Tables (Terraform)                    │      │
│  │ ✓ Tests: route_tables.tftest.hcl                 │      │
│  │   - Route table creation                          │      │
│  │   - CIDR → Host mappings                          │      │
│  │   - VirtualAppliance next hop                     │      │
│  │   - Subnet association                            │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │ Network Interface IP Forwarding (Terraform)       │      │
│  │ ✓ Tests: ip_forwarding.tftest.hcl                │      │
│  │   - VM NIC IP forwarding                          │      │
│  │   - Management NIC IP forwarding                  │      │
│  │   - Static IP configuration                       │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   KVM Host Configuration                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │ Route Setup Script (Bash/BATS)                    │      │
│  │ ✓ Tests: test_setup_routes.bats                  │      │
│  │   - IP extraction from mgmt bridge                │      │
│  │   - Route parsing and validation                  │      │
│  │   - Persistent systemd configuration              │      │
│  │   - Multiple route handling                       │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │ OVS Bridge Configuration (Ansible)                │      │
│  │ ✓ Tests: test_ovs_bridge.yml                     │      │
│  │   - Bridge creation                               │      │
│  │   - IP migration eth1 → mgmt                      │      │
│  │   - Netplan configuration                         │      │
│  │   - Conditional execution                         │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
│  ┌───────────────────────────────────────────────────┐      │
│  │ iptables-persistent Configuration (Ansible)       │      │
│  │ ✓ Tests: test_iptables_persistent.yml            │      │
│  │   - Package installation                          │      │
│  │   - NAT and FORWARD rules                         │      │
│  │   - Libvirt chain preservation                    │      │
│  │   - Rule persistence via netfilter-persistent     │      │
│  └───────────────────────────────────────────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Test Requirements Met

### ✅ Test Case 1: Azure Route Tables
**Requirement:** Verify that Azure Route Tables are correctly configured to direct nested VM traffic to the appropriate KVM host.

**Implementation:** `tests/terraform/route_tables.tftest.hcl`
- Validates route creation, CIDR ranges, next hop configuration
- Tests 1-10 VM scenarios

### ✅ Test Case 2: IP Forwarding
**Requirement:** Verify that ip_forwarding is enabled on the KVM host network interfaces.

**Implementation:** `tests/terraform/ip_forwarding.tftest.hcl`
- Validates enable_ip_forwarding=true on all NICs
- Tests VM and management interfaces separately

### ✅ Test Case 3: Route Setup Script
**Requirement:** Verify that the setup-nested-vm-routes.sh script correctly adds persistent routes for nested VM IP ranges on the KVM hosts.

**Implementation:** `tests/bash/test_setup_routes.bats`
- 15 test cases covering all script functionality
- Validates IP extraction, route parsing, persistence

### ✅ Test Case 4: OVS Bridge Configuration
**Requirement:** Verify that the Ansible playbook correctly configures the OVS mgmt bridge and moves the IP address from eth1 to mgmt.

**Implementation:** `tests/ansible/test_ovs_bridge.yml`
- 15 tests covering bridge creation, IP migration
- Validates commands and conditional execution

### ✅ Test Case 5: iptables-persistent Configuration
**Requirement:** Verify that iptables-persistent is used to preserve firewall rules on the KVM hosts while maintaining libvirt compatibility.

**Implementation:** `tests/ansible/test_iptables_persistent.yml`
- 15 tests covering iptables-persistent configuration
- Validates package installation, NAT rules, FORWARD rules, libvirt compatibility

## Additional Files

### Documentation
- **`tests/README.md`** - Comprehensive test documentation with prerequisites, usage, and troubleshooting

### Test Runner
- **`tests/run_all_tests.sh`** - Automated test runner for all test suites with colored output and summary

## CI/CD Integration

The test suite is designed for easy integration into CI/CD pipelines:

- GitHub Actions ready
- Exit codes for pass/fail
- Colored output with summaries
- Dependency checking

## Next Steps

1. **Run the tests:**
   ```bash
   ./tests/run_all_tests.sh
   ```

2. **Install missing dependencies if needed:**
   - Terraform 1.6.0+
   - BATS: `brew install bats-core`
   - Ansible: `pip install ansible`

3. **Integrate into CI/CD pipeline** using the provided GitHub Actions example

4. **Add more tests** as infrastructure evolves

## Notes

- All tests are **unit tests** - they test configuration and logic without deploying actual infrastructure
- Tests use mocking and assertions to validate correctness
- Tests are idempotent and can be run repeatedly
- No Azure credentials required for testing
