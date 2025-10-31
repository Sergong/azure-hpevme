# Troubleshooting Nested VM Internet Connectivity

## Problem
Nested VMs (e.g., 10.0.1.20 on vme-kvm-vm1) cannot reach the internet.

## Root Cause
The current configuration uses Azure Route Tables for inter-host communication but doesn't include NAT for internet-bound traffic. Nested VMs need NAT to access external networks through the KVM host's public interface (eth0).

## Solution

### Quick Fix (Run on KVM hosts)
```bash
# Copy the NAT setup script to your KVM hosts
ansible all -m copy -a 'src=setup-nested-vm-nat.sh dest=/tmp/setup-nested-vm-nat.sh mode=0755'

# Run the NAT configuration script
ansible all -m shell -a 'sudo /tmp/setup-nested-vm-nat.sh'
```

### What the Script Does

1. **Enables IP forwarding** (already should be enabled)
2. **Adds iptables MASQUERADE rule** - Makes nested VM traffic appear to come from eth0
3. **Configures FORWARD rules** - Allows traffic from mgmt bridge to eth0 and back
4. **Makes rules persistent** - Installs and configures iptables-persistent

### Manual Configuration (if needed)

On each KVM host:

```bash
# 1. Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

# 2. Add NAT rule
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# 3. Allow forwarding from mgmt bridge to eth0
sudo iptables -A FORWARD -i mgmt -o eth0 -j ACCEPT

# 4. Allow return traffic
sudo iptables -A FORWARD -i eth0 -o mgmt -m state --state RELATED,ESTABLISHED -j ACCEPT

# 5. Allow traffic within mgmt bridge
sudo iptables -A FORWARD -i mgmt -o mgmt -j ACCEPT

# 6. Make rules persistent
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

## Verification Steps

### 1. Check NAT Rule on KVM Host
```bash
sudo iptables -t nat -L POSTROUTING -v -n
```
Expected output should include:
```
MASQUERADE  all  --  *  eth0  0.0.0.0/0  0.0.0.0/0
```

### 2. Check Forward Rules
```bash
sudo iptables -L FORWARD -v -n
```
Expected output should include:
```
ACCEPT  all  --  mgmt  eth0  0.0.0.0/0  0.0.0.0/0
ACCEPT  all  --  eth0  mgmt  0.0.0.0/0  0.0.0.0/0  state RELATED,ESTABLISHED
ACCEPT  all  --  mgmt  mgmt  0.0.0.0/0  0.0.0.0/0
```

### 3. Check IP Forwarding
```bash
sysctl net.ipv4.ip_forward
```
Expected: `net.ipv4.ip_forward = 1`

### 4. Test from Nested VM
From inside the nested VM (10.0.1.20):

```bash
# Test DNS resolution
ping -c 2 8.8.8.8

# Test name resolution
ping -c 2 google.com

# Check default gateway
ip route show

# Verify DNS
cat /etc/resolv.conf
```

## Common Issues

### Issue 1: Nested VM has no default route
**Symptom:** `ip route show` doesn't show a default gateway

**Fix:** Add default route in nested VM pointing to KVM host:
```bash
# Inside nested VM
sudo ip route add default via 10.0.1.10  # Use your KVM host IP
```

### Issue 2: DNS not configured in nested VM
**Symptom:** `ping 8.8.8.8` works but `ping google.com` fails

**Fix:** Configure DNS in nested VM:
```bash
# Inside nested VM
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf
```

### Issue 3: iptables rules not persisting after reboot
**Symptom:** Internet works until KVM host reboots

**Fix:** Ensure iptables-persistent is installed and rules are saved:
```bash
sudo apt install -y iptables-persistent
sudo netfilter-persistent save
```

### Issue 4: UFW blocking forwarded traffic
**Symptom:** NAT rules exist but traffic still blocked

**Fix:** Ensure UFW allows routed traffic (should be done by playbook):
```bash
sudo ufw default allow routed
sudo ufw status verbose
```

## Testing Connectivity

### From Nested VM (10.0.1.20)

```bash
# 1. Test local KVM host
ping -c 2 10.0.1.10

# 2. Test other KVM host
ping -c 2 10.0.1.11

# 3. Test Azure DNS (in VNet)
ping -c 2 168.63.129.16

# 4. Test internet via IP
ping -c 2 8.8.8.8

# 5. Test internet via DNS
ping -c 2 google.com

# 6. Test HTTP
curl -I http://google.com
```

### From KVM Host

Check if traffic from nested VM is being NATed:

```bash
# Watch NAT translations in real-time
sudo watch -n 1 'iptables -t nat -L POSTROUTING -v -n'

# Check connection tracking
sudo conntrack -L | grep 10.0.1.20
```

## Network Architecture with NAT

```
Nested VM (10.0.1.20)
  |
  | IP: 10.0.1.20
  | Gateway: 10.0.1.10
  | DNS: 8.8.8.8
  v
mgmt bridge (10.0.1.10)
  |
  | [iptables NAT]
  | Source: 10.0.1.20 -> 10.0.2.X (eth0 IP)
  v
eth0 (KVM host management interface)
  |
  | Has public IP
  v
Internet
```

## Traffic Flow

1. **Nested VM** sends packet to 8.8.8.8 from 10.0.1.20
2. **Default route** forwards to gateway 10.0.1.10 (KVM host)
3. **mgmt bridge** receives packet
4. **iptables FORWARD** allows mgmt -> eth0
5. **iptables NAT** changes source IP from 10.0.1.20 to eth0's IP
6. **eth0** sends packet to internet
7. **Return path**: Internet -> eth0 -> NAT (restore dest IP) -> mgmt -> nested VM

## Re-running Configuration

If you've updated the playbook, re-run it:

```bash
ansible-playbook -i inventory.yml playbook-install-kvm.yml
```

Or just the NAT configuration:

```bash
ansible all -m shell -a 'sudo /tmp/setup-nested-vm-nat.sh'
```

## Verification Checklist

- [ ] IP forwarding enabled: `sysctl net.ipv4.ip_forward = 1`
- [ ] MASQUERADE rule exists in NAT table
- [ ] FORWARD rules allow mgmt <-> eth0
- [ ] iptables-persistent installed
- [ ] UFW allows routed traffic
- [ ] Nested VM has default gateway set
- [ ] Nested VM has DNS configured
- [ ] Can ping 8.8.8.8 from nested VM
- [ ] Can ping google.com from nested VM

## Additional Notes

### Why NAT is Needed
- Azure doesn't know about nested VM IPs (10.0.1.20) outside the /28 ranges
- Internet routers don't have routes back to 10.0.1.20
- NAT makes traffic appear to come from the KVM host's public IP
- This is standard practice for nested virtualization

### Route Tables vs NAT
- **Route Tables**: Handle traffic WITHIN Azure VNet (10.0.0.0/16)
- **NAT**: Handles traffic TO/FROM the internet
- Both are needed for full connectivity

### Alternative: Azure NAT Gateway
Instead of host-based NAT, you could use Azure NAT Gateway attached to the subnet, but this requires additional Azure resources and costs.
