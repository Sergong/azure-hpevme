# Unit Tests for Azure KVM VXLAN Overlay Infrastructure

This directory contains the unit tests for the Azure KVM VXLAN overlay infrastructure. The tests are written using OpenTofu's testing framework, Ansible, and BATS (Bash Automated Testing System).

## Test Coverage

The test suite covers the following key areas of the infrastructure:

### 1. Azure Infrastructure (OpenTofu)

- **`tests/route_tables.tftest.hcl`**: Tests the Azure Route Table and User-Defined Route (UDR) for the VXLAN overlay network. It verifies that the route table is created correctly and that the UDR directs overlay traffic to the gateway KVM host.
- **`tests/ip_forwarding.tftest.hcl`**: Tests that IP forwarding is enabled on the network interfaces of the KVM hosts.

### 2. KVM Host Configuration (Ansible)

- **`tests/ansible/test_ovs_bridge.yml`**: Tests the `netplan` configuration for the OVS bridge and VXLAN tunnel. It verifies that the `99-ovs.yaml` file is used and that it contains the correct configuration for the bridge, tunnel, and Azure DNS route.
- **`tests/ansible/test_nat_config.yml`**: Tests the NAT configuration on the gateway KVM host. It verifies that the `setup-nested-vm-nat.sh` script is executed only on the gateway and that it is idempotent.
- **`tests/ansible/test_iptables_persistent.yml`**: Tests the installation of `iptables-persistent` and the saving of `iptables` rules.

### 3. NAT Script (BATS)

- **`tests/bash/test_setup_nat.bats`**: Tests the `setup-nested-vm-nat.sh` script. It verifies that the script correctly configures the `iptables` rules for NAT and that it is idempotent.

## Running the Tests

To run all the tests, you can use the `run_all_tests.sh` script from the project root:

```bash
./tests/run_all_tests.sh
```

You can also run the tests for each component individually. 

### OpenTofu Tests

To run the OpenTofu tests, execute the following command from the project root:

```bash
tofu test
```

See the `QUICK_REFERENCE.md` file for more details on running individual tests.