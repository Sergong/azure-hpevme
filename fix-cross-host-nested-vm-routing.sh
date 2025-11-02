#!/bin/bash
# Fix cross-host nested VM routing issues
# This ensures KVM hosts can forward traffic to nested VMs on other hosts

set -e

echo "Fixing cross-host nested VM routing..."

# Disable ICMP redirects (prevents routing loops)
sysctl -w net.ipv4.conf.all.send_redirects=0
sysctl -w net.ipv4.conf.mgmt.send_redirects=0
echo "net.ipv4.conf.all.send_redirects=0" >> /etc/sysctl.d/99-nested-vm-routing.conf
echo "net.ipv4.conf.mgmt.send_redirects=0" >> /etc/sysctl.d/99-nested-vm-routing.conf

# Enable proxy ARP on mgmt bridge
sysctl -w net.ipv4.conf.mgmt.proxy_arp=1
echo "net.ipv4.conf.mgmt.proxy_arp=1" >> /etc/sysctl.d/99-nested-vm-routing.conf

# Ensure IP forwarding is enabled
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-nested-vm-routing.conf

# Add iptables rules to explicitly allow cross-host nested VM traffic
# Allow traffic from other KVM hosts to local nested VMs
iptables -C FORWARD -i mgmt -o mgmt -j ACCEPT 2>/dev/null || \
  iptables -I FORWARD 1 -i mgmt -o mgmt -j ACCEPT

echo "Cross-host nested VM routing fixed!"
echo "Settings saved to /etc/sysctl.d/99-nested-vm-routing.conf"

# Save iptables rules
if command -v netfilter-persistent &> /dev/null; then
    netfilter-persistent save
    echo "iptables rules saved"
fi
