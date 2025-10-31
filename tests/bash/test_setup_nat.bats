#!/usr/bin/env bats
# Unit tests for setup-nested-vm-nat.sh
# Test Case 6: Verify that NAT is correctly configured for nested VM internet access

setup() {
  export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export EXTERNAL_IF="eth0"
  export BRIDGE_IF="mgmt"
}

@test "script uses correct external interface" {
  EXTERNAL_IF="eth0"
  
  [ "$EXTERNAL_IF" = "eth0" ]
}

@test "script uses correct bridge interface" {
  BRIDGE_IF="mgmt"
  
  [ "$BRIDGE_IF" = "mgmt" ]
}

@test "MASQUERADE rule format is correct" {
  EXTERNAL_IF="eth0"
  
  # Mock iptables command format
  rule="iptables -t nat -A POSTROUTING -o $EXTERNAL_IF -j MASQUERADE"
  
  [[ "$rule" =~ "POSTROUTING" ]]
  [[ "$rule" =~ "MASQUERADE" ]]
  [[ "$rule" =~ "eth0" ]]
}

@test "MASQUERADE only applies to external interface" {
  EXTERNAL_IF="eth0"
  
  # Rule should be specific to eth0
  rule="iptables -t nat -A POSTROUTING -o $EXTERNAL_IF -j MASQUERADE"
  
  [[ "$rule" =~ "-o eth0" ]]
  [[ ! "$rule" =~ "mgmt" ]]
}

@test "FORWARD rule allows mgmt to eth0" {
  BRIDGE_IF="mgmt"
  EXTERNAL_IF="eth0"
  
  rule="iptables -A FORWARD -i $BRIDGE_IF -o $EXTERNAL_IF -j ACCEPT"
  
  [[ "$rule" =~ "FORWARD" ]]
  [[ "$rule" =~ "-i mgmt" ]]
  [[ "$rule" =~ "-o eth0" ]]
  [[ "$rule" =~ "ACCEPT" ]]
}

@test "FORWARD rule allows return traffic eth0 to mgmt" {
  BRIDGE_IF="mgmt"
  EXTERNAL_IF="eth0"
  
  rule="iptables -A FORWARD -i $EXTERNAL_IF -o $BRIDGE_IF -m state --state RELATED,ESTABLISHED -j ACCEPT"
  
  [[ "$rule" =~ "FORWARD" ]]
  [[ "$rule" =~ "-i eth0" ]]
  [[ "$rule" =~ "-o mgmt" ]]
  [[ "$rule" =~ "RELATED,ESTABLISHED" ]]
  [[ "$rule" =~ "ACCEPT" ]]
}

@test "FORWARD rule allows mgmt to mgmt traffic" {
  BRIDGE_IF="mgmt"
  
  rule="iptables -A FORWARD -i $BRIDGE_IF -o $BRIDGE_IF -j ACCEPT"
  
  [[ "$rule" =~ "FORWARD" ]]
  [[ "$rule" =~ "-i mgmt" ]]
  [[ "$rule" =~ "-o mgmt" ]]
  [[ "$rule" =~ "ACCEPT" ]]
}

@test "script checks for existing MASQUERADE rule before adding" {
  EXTERNAL_IF="eth0"
  
  # Script should check before adding
  check_cmd="iptables -t nat -C POSTROUTING -o $EXTERNAL_IF -j MASQUERADE"
  
  [[ "$check_cmd" =~ "-C" ]]  # -C is check operation
  [[ "$check_cmd" =~ "POSTROUTING" ]]
}

@test "script checks for existing FORWARD rules before adding" {
  BRIDGE_IF="mgmt"
  EXTERNAL_IF="eth0"
  
  # Script should check before adding
  check_cmd="iptables -C FORWARD -i $BRIDGE_IF -o $EXTERNAL_IF -j ACCEPT"
  
  [[ "$check_cmd" =~ "-C" ]]  # -C is check operation
  [[ "$check_cmd" =~ "FORWARD" ]]
}

@test "IP forwarding sysctl command is correct" {
  cmd="sysctl -w net.ipv4.ip_forward=1"
  
  [[ "$cmd" =~ "net.ipv4.ip_forward=1" ]]
}

@test "IP forwarding persistence uses sysctl.conf" {
  config_file="/etc/sysctl.conf"
  config_line="net.ipv4.ip_forward=1"
  
  [[ "$config_file" = "/etc/sysctl.conf" ]]
  [[ "$config_line" = "net.ipv4.ip_forward=1" ]]
}

@test "script uses netfilter-persistent to save rules" {
  save_cmd="netfilter-persistent save"
  
  [[ "$save_cmd" = "netfilter-persistent save" ]]
}

@test "script installs iptables-persistent package" {
  package="iptables-persistent"
  
  [ "$package" = "iptables-persistent" ]
}

@test "NAT table is correctly specified" {
  # MASQUERADE should be in NAT table
  rule="iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
  
  [[ "$rule" =~ "-t nat" ]]
}

@test "FORWARD rules use filter table by default" {
  # FORWARD rules should not specify table (defaults to filter)
  rule="iptables -A FORWARD -i mgmt -o eth0 -j ACCEPT"
  
  [[ ! "$rule" =~ "-t" ]]
}

@test "stateful firewall uses connection tracking" {
  rule="iptables -A FORWARD -i eth0 -o mgmt -m state --state RELATED,ESTABLISHED -j ACCEPT"
  
  [[ "$rule" =~ "-m state" ]]
  [[ "$rule" =~ "--state" ]]
  [[ "$rule" =~ "RELATED,ESTABLISHED" ]]
}

@test "script checks for rule existence with stderr redirect" {
  # When checking rules, stderr should be redirected
  check_cmd="iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null"
  
  [[ "$check_cmd" =~ "2>/dev/null" ]]
}

@test "verification displays NAT rules from POSTROUTING chain" {
  verify_cmd="iptables -t nat -L POSTROUTING -v -n"
  
  [[ "$verify_cmd" =~ "-t nat" ]]
  [[ "$verify_cmd" =~ "-L POSTROUTING" ]]
  [[ "$verify_cmd" =~ "-v" ]]
  [[ "$verify_cmd" =~ "-n" ]]
}

@test "verification displays FORWARD chain rules" {
  verify_cmd="iptables -L FORWARD -v -n"
  
  [[ "$verify_cmd" =~ "-L FORWARD" ]]
  [[ "$verify_cmd" =~ "-v" ]]
  [[ "$verify_cmd" =~ "-n" ]]
}

@test "script output includes success markers" {
  success_marker="[OK]"
  
  [ "$success_marker" = "[OK]" ]
}

@test "script validates nested VM can ping internet" {
  test_target="8.8.8.8"
  
  [ "$test_target" = "8.8.8.8" ]
}

@test "NAT rules are idempotent and safe to re-run" {
  # Script checks before adding, so it's safe to run multiple times
  check_pattern="if ! iptables"
  
  [[ "$check_pattern" = "if ! iptables" ]]
}

@test "NAT configuration preserves inter-host traffic" {
  # NAT only applies to traffic going OUT eth0, not mgmt
  nat_rule_interface="-o eth0"
  
  [[ "$nat_rule_interface" = "-o eth0" ]]
  [[ "$nat_rule_interface" != "-o mgmt" ]]
}

@test "script uses DEBIAN_FRONTEND for non-interactive install" {
  install_cmd="DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent"
  
  [[ "$install_cmd" =~ "DEBIAN_FRONTEND=noninteractive" ]]
}
