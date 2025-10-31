# Quick Reference - Unit Tests

## Run All Tests
```bash
./tests/run_all_tests.sh
```

## Run Individual Test Suites

### Terraform Tests
```bash
# All Terraform tests
cd tests/terraform && terraform test

# Specific test file
terraform test -filter=route_tables.tftest.hcl
terraform test -filter=ip_forwarding.tftest.hcl
```

### Bash/BATS Tests
```bash
# All BATS tests
cd tests/bash && bats test_setup_routes.bats

# Specific test
bats test_setup_routes.bats --filter "script extracts host IP"

# Verbose output
bats --trace test_setup_routes.bats
```

### Ansible Tests
```bash
# All Ansible tests
cd tests/ansible
ansible-playbook test_ovs_bridge.yml test_ufw_rules.yml

# Individual test files
ansible-playbook test_ovs_bridge.yml
ansible-playbook test_ufw_rules.yml

# Verbose output
ansible-playbook -vvv test_ovs_bridge.yml
```

## Prerequisites Installation

### macOS
```bash
# Terraform
brew install terraform

# BATS
brew install bats-core

# Ansible
pip3 install ansible
ansible-galaxy collection install community.general
```

### Ubuntu/Debian
```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# BATS
sudo apt install bats

# Ansible
sudo apt install ansible
ansible-galaxy collection install community.general
```

## Test Coverage

| Test Case | File | Test Count |
|-----------|------|------------|
| 1. Azure Route Tables | `terraform/route_tables.tftest.hcl` | 6 scenarios |
| 2. IP Forwarding | `terraform/ip_forwarding.tftest.hcl` | 5 scenarios |
| 3. Route Setup Script | `bash/test_setup_routes.bats` | 15 tests |
| 4. OVS Bridge Config | `ansible/test_ovs_bridge.yml` | 15 tests |
| 5. UFW Rules | `ansible/test_ufw_rules.yml` | 15 tests |

## Common Commands

```bash
# Check test framework versions
terraform version
bats --version
ansible --version

# Make scripts executable
chmod +x tests/run_all_tests.sh
chmod +x tests/bash/test_setup_routes.bats

# Debug Terraform tests
TF_LOG=DEBUG terraform test

# Run Ansible tests locally (no remote hosts needed)
ansible-playbook test_ovs_bridge.yml
```

## Expected Output

### Success
```
✓ ALL TESTS PASSED!
Total test suites: 4
Passed: 4
Failed: 0
```

### Individual Test Success
- **Terraform:** `Success! X passed, 0 failed.`
- **BATS:** `15 tests, 0 failures`
- **Ansible:** `ok=30 changed=0 failed=0`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `terraform: command not found` | Install Terraform (see prerequisites) |
| `bats: command not found` | Install BATS: `brew install bats-core` |
| `ansible-playbook: command not found` | Install Ansible: `pip install ansible` |
| Terraform test fails | Run `terraform init` in project root |
| Ansible collection missing | `ansible-galaxy collection install community.general` |

## File Structure
```
tests/
├── README.md                     # Full documentation
├── QUICK_REFERENCE.md           # This file
├── TEST_SUMMARY.md              # Detailed test coverage
├── run_all_tests.sh             # Run all tests
├── terraform/
│   ├── route_tables.tftest.hcl
│   └── ip_forwarding.tftest.hcl
├── bash/
│   └── test_setup_routes.bats
└── ansible/
    ├── test_ovs_bridge.yml
    └── test_ufw_rules.yml
```

## Documentation Links
- Full README: `tests/README.md`
- Test Summary: `tests/TEST_SUMMARY.md`
- Project Networking Docs: `NESTED-VM-NETWORKING.md`
