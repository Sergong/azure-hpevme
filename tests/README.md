# Unit Tests for Azure KVM Nested VM Networking

This directory contains comprehensive unit tests for the Azure KVM nested VM networking infrastructure.

## Test Coverage

The test suite covers the following test cases:

### 1. Azure Route Tables Configuration (Terraform)
**File:** `terraform/route_tables.tftest.hcl`

Tests that Azure Route Tables are correctly configured to direct nested VM traffic to the appropriate KVM host.

- Verifies route table creation
- Validates route count matches VM count
- Confirms correct IP address prefixes (CIDR ranges)
- Ensures routes use VirtualAppliance next hop type
- Validates route-to-host IP mappings
- Tests route table subnet association

### 2. IP Forwarding Configuration (Terraform)
**File:** `terraform/ip_forwarding.tftest.hcl`

Tests that IP forwarding is enabled on the KVM host network interfaces.

- Verifies `enable_ip_forwarding = true` on VM traffic NICs
- Verifies `enable_ip_forwarding = true` on management NICs
- Tests all NICs across multiple VM counts
- Validates static IP configuration

### 3. Setup Routes Script (Bash)
**File:** `bash/test_setup_routes.bats`

Tests the `setup-nested-vm-routes.sh` script that adds persistent routes for nested VM IP ranges.

- Host IP extraction from mgmt bridge
- Route entry parsing (CIDR:IP format)
- Skipping routes for own IP range
- Detecting existing routes
- Creating persistent systemd network configuration
- Handling multiple route entries
- CIDR and IP address validation

### 4. OVS Bridge Configuration (Ansible)
**File:** `ansible/test_ovs_bridge.yml`

Tests the Ansible playbook's OVS mgmt bridge configuration and IP address migration from eth1.

- OVS bridge existence check
- IP extraction from eth1 interface
- Bridge creation commands
- Port addition to bridge
- IP assignment to bridge
- IP flushing from eth1
- Netplan configuration updates
- Conditional task execution

### 5. iptables-persistent Configuration (Ansible)
**File:** `ansible/test_iptables_persistent.yml`

Tests iptables-persistent configuration for firewall rules that preserve libvirt chains.

- iptables-persistent and netfilter-persistent package installation
- UFW exclusion (incompatible with libvirt)
- NAT MASQUERADE rule for internet access
- FORWARD rules for nested VM traffic
- Rule persistence via netfilter-persistent save
- Libvirt chain compatibility
- Nested VM networking requirements

## Prerequisites

### For Terraform Tests
```bash
# Terraform 1.6.0+ with testing support
terraform version
```

### For Bash Tests (BATS)
```bash
# Install BATS (Bash Automated Testing System)
# macOS
brew install bats-core

# Ubuntu/Debian
sudo apt-get install bats

# Or install from source
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### For Ansible Tests
```bash
# Ansible 2.9+
ansible --version

# Install required collections
ansible-galaxy collection install ansible.builtin
ansible-galaxy collection install community.general
```

## Running the Tests

### Run All Terraform Tests
```bash
cd tests/terraform
terraform init
terraform test
```

### Run Specific Terraform Test Files
```bash
# Test route tables
terraform test -filter=route_tables.tftest.hcl

# Test IP forwarding
terraform test -filter=ip_forwarding.tftest.hcl
```

### Run Bash/BATS Tests
```bash
cd tests/bash
bats test_setup_routes.bats
```

Run specific test:
```bash
bats test_setup_routes.bats --filter "script extracts host IP"
```

### Run Ansible Tests
```bash
# Run OVS bridge tests
cd tests/ansible
ansible-playbook test_ovs_bridge.yml

# Run iptables-persistent tests
ansible-playbook test_iptables_persistent.yml

# Run all Ansible tests
ansible-playbook test_ovs_bridge.yml test_iptables_persistent.yml
```

### Run All Tests (Comprehensive)
```bash
# From project root
./tests/run_all_tests.sh
```

## Test Structure

```
tests/
├── README.md                          # This file
├── run_all_tests.sh                   # Script to run all tests
├── terraform/
│   ├── route_tables.tftest.hcl       # Route table tests
│   └── ip_forwarding.tftest.hcl      # IP forwarding tests
├── bash/
│   └── test_setup_routes.bats        # Bash script tests
└── ansible/
    ├── test_ovs_bridge.yml           # OVS configuration tests
    └── test_iptables_persistent.yml  # iptables-persistent tests
```

## Test Results

### Expected Output

**Terraform Tests:**
```
Success! 15 passed, 0 failed.
```

**BATS Tests:**
```
✓ script extracts host IP from mgmt bridge
✓ script parses route entries correctly
✓ script skips routes for own IP range
...
15 tests, 0 failures
```

**Ansible Tests:**
```
PLAY RECAP *********************************************************************
localhost : ok=30   changed=0    unreachable=0    failed=0    skipped=0
```

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

### GitHub Actions Example
```yaml
name: Test Infrastructure

on: [push, pull_request]

jobs:
  test-terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: cd tests/terraform && terraform test

  test-bash:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: sudo apt-get install bats
      - run: cd tests/bash && bats test_setup_routes.bats

  test-ansible:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: pip install ansible
      - run: cd tests/ansible && ansible-playbook test_*.yml
```

## Debugging Tests

### Verbose Terraform Tests
```bash
TF_LOG=DEBUG terraform test
```

### Verbose BATS Tests
```bash
bats --trace test_setup_routes.bats
```

### Verbose Ansible Tests
```bash
ansible-playbook -vvv test_ovs_bridge.yml
```

## Adding New Tests

### Terraform Test Template
```hcl
run "verify_new_feature" {
  command = plan

  variables {
    # Test-specific variables
  }

  assert {
    condition     = # Your condition
    error_message = "Error message"
  }
}
```

### BATS Test Template
```bash
@test "description of test" {
  # Test setup
  expected="value"
  
  # Execute test logic
  actual=$(some_command)
  
  # Assertion
  [ "$actual" = "$expected" ]
}
```

### Ansible Test Template
```yaml
- name: Test description
  ansible.builtin.set_fact:
    test_value: "expected"
  
- name: Assert condition
  ansible.builtin.assert:
    that:
      - test_value == "expected"
    fail_msg: "Test failed"
    success_msg: "Test passed"
```

## Contributing

When adding new features to the infrastructure:

1. Write tests first (TDD approach)
2. Ensure all existing tests pass
3. Add documentation for new tests
4. Update this README if needed

## Troubleshooting

### Terraform Tests Fail
- Ensure you're using Terraform 1.6.0+
- Run `terraform init` in the test directory
- Check variable values match your environment

### BATS Tests Fail
- Verify BATS is installed: `bats --version`
- Ensure test file is executable: `chmod +x test_setup_routes.bats`
- Check bash version: `bash --version` (requires 4.0+)

### Ansible Tests Fail
- Verify Ansible version: `ansible --version`
- Install required collections: `ansible-galaxy collection install community.general`
- Run with verbosity for debugging: `ansible-playbook -vvv test_file.yml`

## References

- [Terraform Testing Framework](https://developer.hashicorp.com/terraform/language/tests)
- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Ansible Testing Strategies](https://docs.ansible.com/ansible/latest/dev_guide/testing.html)
- [Project Networking Documentation](../NESTED-VM-NETWORKING.md)
