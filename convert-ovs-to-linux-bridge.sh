#!/bin/bash
# Convert from OpenVSwitch to Linux bridge for better hairpin routing support

set -e

echo "Converting from OVS to Linux bridge..."

# Get hostname to determine which IP to use
HOSTNAME=$(hostname)
if [[ "$HOSTNAME" == "vme-kvm-vm1" ]]; then
    BRIDGE_IP="10.0.1.10"
elif [[ "$HOSTNAME" == "vme-kvm-vm2" ]]; then
    BRIDGE_IP="10.0.1.11"
else
    echo "Unknown hostname: $HOSTNAME"
    exit 1
fi

echo "Hostname: $HOSTNAME, Bridge IP: $BRIDGE_IP"

# Stop any running VMs
echo "Checking for running VMs..."
RUNNING_VMS=$(virsh list --name | grep -v '^$' || true)
if [ -n "$RUNNING_VMS" ]; then
    echo "Warning: Found running VMs. Stopping them..."
    echo "$RUNNING_VMS" | while read vm; do
        [ -n "$vm" ] && virsh shutdown "$vm"
    done
    sleep 5
fi

# Remove OVS bridge
echo "Removing OVS bridge..."
if ovs-vsctl br-exists mgmt 2>/dev/null; then
    # Remove eth1 from bridge first
    ovs-vsctl --if-exists del-port mgmt eth1
    # Delete the bridge
    ovs-vsctl del-br mgmt
fi

# Install bridge-utils if not present
echo "Installing bridge-utils..."
apt-get install -y bridge-utils

# Create Linux bridge
echo "Creating Linux bridge 'mgmt'..."
brctl addbr mgmt || true

# Add eth1 to bridge
echo "Adding eth1 to bridge..."
brctl addif mgmt eth1

# Bring eth1 up (no IP)
ip link set eth1 up

# Bring bridge up
ip link set mgmt up

# Add IP address to bridge with /32
echo "Adding IP ${BRIDGE_IP}/32 to bridge..."
ip addr add ${BRIDGE_IP}/32 dev mgmt

# Add specific routes
echo "Adding specific routes..."
if [[ "$HOSTNAME" == "vme-kvm-vm1" ]]; then
    # Routes for vm1
    ip route add 10.0.1.11/32 dev mgmt || true
    ip route add 10.0.1.16/28 dev mgmt || true
    ip route add 10.0.1.48/28 via 10.0.1.11 dev mgmt || true
else
    # Routes for vm2
    ip route add 10.0.1.10/32 dev mgmt || true
    ip route add 10.0.1.16/28 via 10.0.1.10 dev mgmt || true
    ip route add 10.0.1.48/28 dev mgmt || true
fi

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Disable ICMP redirects
sysctl -w net.ipv4.conf.all.send_redirects=0
sysctl -w net.ipv4.conf.mgmt.send_redirects=0

# Enable proxy ARP
sysctl -w net.ipv4.conf.mgmt.proxy_arp=1

echo "Linux bridge configured successfully!"
echo "Bridge interface:"
ip addr show mgmt
echo ""
echo "Routes:"
ip route show | grep mgmt

echo ""
echo "Note: This configuration is temporary. Update netplan for persistence."
