#!/usr/bin/env bash
# Setup NAT for nested VMs to access the internet
# This allows nested VMs to reach external networks through the KVM host

set -euo pipefail

echo "=== Configuring NAT for Nested VM Internet Access ==="

# Network interfaces
EXTERNAL_IF="eth0"      # Management interface with internet access
BRIDGE_IF="mgmt"        # OVS bridge for nested VMs

# 1. Enable IP forwarding (should already be set, but ensure it)
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

# Make IP forwarding persistent
if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo "[OK] IP forwarding made persistent in /etc/sysctl.conf"
else
    echo "[OK] IP forwarding already persistent"
fi

# 2. Configure iptables NAT rules for internet access
echo ""
echo "Configuring iptables NAT rules..."

# Check if MASQUERADE rule already exists
if ! iptables -t nat -C POSTROUTING -o "$EXTERNAL_IF" -j MASQUERADE 2>/dev/null; then
    # MASQUERADE: Makes nested VM traffic appear to come from eth0's IP
    iptables -t nat -A POSTROUTING -o "$EXTERNAL_IF" -j MASQUERADE
    echo "[OK] Added MASQUERADE rule for $EXTERNAL_IF"
else
    echo "[OK] MASQUERADE rule already exists"
fi

# Allow forwarding from mgmt bridge to external interface
if ! iptables -C FORWARD -i "$BRIDGE_IF" -o "$EXTERNAL_IF" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$BRIDGE_IF" -o "$EXTERNAL_IF" -j ACCEPT
    echo "[OK] Allow forward from $BRIDGE_IF to $EXTERNAL_IF"
else
    echo "[OK] Forward rule $BRIDGE_IF to $EXTERNAL_IF already exists"
fi

# Allow return traffic (established connections)
if ! iptables -C FORWARD -i "$EXTERNAL_IF" -o "$BRIDGE_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$EXTERNAL_IF" -o "$BRIDGE_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT
    echo "[OK] Allow return traffic $EXTERNAL_IF to $BRIDGE_IF"
else
    echo "[OK] Return traffic rule already exists"
fi

# Allow forwarding from management subnet (via eth0) to nested VMs (mgmt bridge)
if ! iptables -C FORWARD -s 10.0.2.0/24 -i "$EXTERNAL_IF" -o "$BRIDGE_IF" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -s 10.0.2.0/24 -i "$EXTERNAL_IF" -o "$BRIDGE_IF" -j ACCEPT
    echo "[OK] Allow forwarding from management subnet (10.0.2.0/24) to $BRIDGE_IF"
else
    echo "[OK] Management subnet forwarding rule already exists"
fi

# Allow return traffic from nested VMs to management subnet
if ! iptables -C FORWARD -d 10.0.2.0/24 -i "$BRIDGE_IF" -o "$EXTERNAL_IF" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -d 10.0.2.0/24 -i "$BRIDGE_IF" -o "$EXTERNAL_IF" -j ACCEPT
    echo "[OK] Allow return traffic from $BRIDGE_IF to management subnet"
else
    echo "[OK] Return traffic to management subnet rule already exists"
fi

# Allow forwarding within the mgmt bridge (for inter-VM communication)
if ! iptables -C FORWARD -i "$BRIDGE_IF" -o "$BRIDGE_IF" -j ACCEPT 2>/dev/null; then
    iptables -A FORWARD -i "$BRIDGE_IF" -o "$BRIDGE_IF" -j ACCEPT
    echo "[OK] Allow forwarding within $BRIDGE_IF"
else
    echo "[OK] Bridge internal forwarding rule already exists"
fi

# 3. Make iptables rules persistent
echo ""
echo "Making iptables rules persistent..."

# Install iptables-persistent if not already installed
if ! dpkg -l | grep -q iptables-persistent; then
    echo "Installing iptables-persistent..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
else
    echo "[OK] iptables-persistent already installed"
fi

# Save current rules
netfilter-persistent save
echo "[OK] iptables rules saved"

# 4. Verify configuration
echo ""
echo "=== Configuration Summary ==="
echo ""
echo "IP Forwarding:"
sysctl net.ipv4.ip_forward

echo ""
echo "NAT Rules:"
iptables -t nat -L POSTROUTING -v -n | grep -A 2 "POSTROUTING"

echo ""
echo "Forward Rules:"
iptables -L FORWARD -v -n | grep -E "(mgmt|eth0)" | head -10

echo ""
echo "=== NAT Configuration Complete ==="
echo ""
echo "Nested VMs should now be able to access the internet through eth0"
echo "Test from nested VM: ping 8.8.8.8"
echo ""
