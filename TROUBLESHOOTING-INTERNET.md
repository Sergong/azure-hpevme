# Troubleshooting Nested VM Internet Connectivity

This guide provides a step-by-step process for diagnosing and resolving internet connectivity issues for nested VMs running on the KVM hosts.

## 1. Check for MTU Issues (Most Common Cause)

**Symptom**: You can ping small packets to the internet (e.g., `ping 8.8.8.8`), but larger connections, such as `dnf update` or `apt update`, hang and time out.

**Cause**: The default MTU (Maximum Transmission Unit) of the nested VM (1500) is too large for the VXLAN tunnel (1450), causing large packets to be dropped.

**Solution**:

1.  **Set the MTU manually** inside the nested VM. The interface name may vary, but it is typically `enp1s0` for modern cloud images.
    ```bash
    sudo ip link set dev enp1s0 mtu 1450
    ```

2.  **Test the connection again**:
    ```bash
    sudo dnf update
    # or
    sudo apt update
    ```

3.  **Make the MTU setting persistent**. This has been done in the `user-data.j2` file, which now includes the MTU setting in the NetworkManager connection profile. If you are using a different cloud-init configuration, you will need to add this setting.

## 2. Verify Nested VM Network Configuration

**Symptom**: The nested VM has no network connectivity at all.

**Checks**:

1.  **IP Address**: Ensure the nested VM has a static IP address from the `192.168.10.0/24` range.
2.  **Default Gateway**: The default gateway for the nested VM must be the IP address of the `mgmt` bridge on the gateway KVM host (`192.168.10.1`).
    ```bash
    # Inside the nested VM
    ip route show
    # Should show: default via 192.168.10.1 dev <interface>
    ```
3.  **DNS**: The nested VM must have a DNS server configured.
    ```bash
    # Inside the nested VM
    cat /etc/resolv.conf
    # Should show a nameserver, e.g., nameserver 8.8.8.8
    ```

## 3. Verify Gateway Host (vme-kvm-vm1) Configuration

**Symptom**: No nested VMs have internet access.

**Checks**:

1.  **IP Forwarding**: Ensure IP forwarding is enabled on the gateway host.
    ```bash
    # On the gateway host (vme-kvm-vm1)
    sysctl net.ipv4.ip_forward
    # Expected output: net.ipv4.ip_forward = 1
    ```

2.  **iptables NAT Rule**: Verify that the `MASQUERADE` rule exists in the `nat` table.
    ```bash
    # On the gateway host
    sudo iptables -t nat -L POSTROUTING -v -n
    # Should include a rule for 192.168.10.0/24 to eth0
    ```

3.  **iptables FORWARD Rules**: Check that traffic is allowed to be forwarded between the `mgmt` bridge and the `eth0` interface.
    ```bash
    # On the gateway host
    sudo iptables -L FORWARD -v -n
    # Should show ACCEPT rules for traffic between mgmt and eth0
    ```

## 4. Verify Connectivity from the Nested VM

Perform these tests in order from within the nested VM:

1.  **Ping the gateway**: `ping 192.168.10.1`
2.  **Ping the KVM host's physical IP**: `ping 10.0.1.4`
3.  **Ping the other KVM host**: `ping 10.0.1.5`
4.  **Ping an internet IP address**: `ping 8.8.8.8`
5.  **Ping a domain name**: `ping google.com`

If any of these steps fail, it will help you pinpoint the location of the problem.