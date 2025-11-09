# Quick Reference - Unit Tests

## Run All Tests

```bash
./tests/run_all_tests.sh
```

## Run Individual Test Suites

### OpenTofu Tests

```bash
# From the project root

# All OpenTofu tests
tofu test

# Specific test file
tofu test -filter=route_tables.tftest.hcl
tofu test -filter=ip_forwarding.tftest.hcl
```

### Ansible Tests

```bash
# All Ansible tests
cd tests/ansible
ansible-playbook test_ovs_bridge.yml test_nat_config.yml test_iptables_persistent.yml

# Individual test files
ansible-playbook test_ovs_bridge.yml
ansible-playbook test_nat_config.yml
ansible-playbook test_iptables_persistent.yml
```

### Bash/BATS Tests

```bash
# All BATS tests
cd tests/bash && bats .
```

## Prerequisites Installation

### macOS

```bash
# OpenTofu
brew install opentofu

# BATS
brew install bats-core

# Ansible
pip3 install ansible
ansible-galaxy collection install community.general
```

### Ubuntu/Debian

```bash
# OpenTofu
wget -O- https://get.opentofu.org/install.sh | bash

# BATS
sudo apt install bats

# Ansible
sudo apt install ansible
ansible-galaxy collection install community.general
```