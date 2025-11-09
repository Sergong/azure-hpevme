# Consistent Disk Naming for Ceph on Azure

## Problem

Azure VMs can have inconsistent device naming for data disks:
- **vme-kvm-vm1**: Data disk is `/dev/sdb`
- **vme-kvm-vm2**: Data disk is `/dev/sda`

This inconsistency occurs because Azure's boot sequence can attach disks in different orders. For Ceph OSDs, which require consistent device paths across all hosts, this is a critical issue.

## Solution: Udev-Based Symlinks

We use **udev rules** to create stable symlinks based on Azure's LUN (Logical Unit Number). This provides consistent device paths regardless of the underlying device name.

### Configuration

The data disk is attached at **LUN 10** on all hosts. A udev rule creates:
- `/dev/azure-data` → Points to the 1TB data disk (LUN 10)
- `/dev/azure-data-part1` → Points to the first partition

### Device Mapping

| Host | Real Device | Stable Symlink | LUN |
|------|-------------|----------------|-----|
| vme-kvm-vm1 | `/dev/sdb` | `/dev/azure-data` | 10 |
| vme-kvm-vm2 | `/dev/sda` | `/dev/azure-data` | 10 |

## Setup

### Automatic Setup (Recommended)

Run the Ansible playbook to configure all hosts:

```bash
ansible-playbook playbook-setup-consistent-disk-naming.yml
```

This will:
1. Copy the udev setup script to all hosts
2. Create udev rules for LUN 10 data disk
3. Reload udev and trigger device discovery
4. Verify symlink creation
5. Create configuration summary at `/root/azure-disk-mapping.txt`

### Manual Setup (If Needed)

On each host:

```bash
# Copy and execute the script
ansible all -m copy -a 'src=setup-azure-disk-udev.sh dest=/tmp/setup-azure-disk-udev.sh mode=0755'
ansible all -m shell -a 'sudo /tmp/setup-azure-disk-udev.sh'
```

## Verification

### Check Symlinks Exist

```bash
# On all hosts
ansible azure_vms -m shell -a "ls -la /dev/azure-data*"
```

Expected output:
```
vme-kvm-vm1:
lrwxrwxrwx 1 root root 3 Oct 31 17:09 /dev/azure-data -> sdb
lrwxrwxrwx 1 root root 4 Oct 31 17:09 /dev/azure-data-part1 -> sdb1

vme-kvm-vm2:
lrwxrwxrwx 1 root root 3 Oct 31 17:09 /dev/azure-data -> sda
lrwxrwxrwx 1 root root 4 Oct 31 17:09 /dev/azure-data-part1 -> sda1
```

### Verify Disk Information

```bash
# Check disk details
ansible azure_vms -m shell -a "lsblk $(readlink -f /dev/azure-data)"
```

### View Configuration Summary

```bash
# On each host
ansible azure_vms -m shell -a "cat /root/azure-disk-mapping.txt"
```

## Using with Ceph

> **Important Note**: To be able to use Ceph, you need at least 3 nodes.


### Ceph OSD Creation

Use the **stable symlink** `/dev/azure-data` for all Ceph operations:

```bash
# Create OSD using ceph-volume (recommended)
ceph-volume lvm create --data /dev/azure-data

# Or prepare and activate separately
ceph-volume lvm prepare --data /dev/azure-data
ceph-volume lvm activate --all

# For BlueStore (modern Ceph)
ceph-volume lvm create --bluestore --data /dev/azure-data
```

### Ceph Configuration Example

In your Ceph deployment playbook or configuration:

```yaml
# Ansible inventory
osd_hosts:
  - host: vme-kvm-vm1
    data_device: /dev/azure-data
  - host: vme-kvm-vm2
    data_device: /dev/azure-data

# All hosts use the same device path!
```

### Checking Ceph OSD Status

```bash
# List OSDs
ceph osd tree

# Check OSD details
ceph osd metadata <osd-id>

# Verify device mapping
ceph-volume lvm list
```

## How It Works

### Udev Rule

The udev rule at `/etc/udev/rules.d/99-azure-data-disk.rules`:

```udev
# Match disk by LUN 10
SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="sd*", \
  ATTRS{device/vendor}=="Msft", ATTRS{device/model}=="Virtual Disk", \
  ENV{ID_PATH}=="*-lun-10", \
  SYMLINK+="azure-data", \
  OPTIONS+="string_escape=replace"

# Match partitions
SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", KERNEL=="sd*[0-9]", \
  ATTRS{device/vendor}=="Msft", ATTRS{device/model}=="Virtual Disk", \
  ENV{ID_PATH}=="*-lun-10", \
  SYMLINK+="azure-data-part%n", \
  OPTIONS+="string_escape=replace"
```

This rule:
1. Matches Azure Virtual Disks by vendor and model
2. Filters by LUN 10 using `ID_PATH`
3. Creates stable symlinks in `/dev/`
4. Persists across reboots

### Azure LUN System

Azure uses LUNs to uniquely identify attached disks:
- **LUN 0-63**: Available for data disks
- **OS Disk**: Typically at LUN 0 or 1 (varies)
- **Our Data Disk**: Fixed at LUN 10 (configured in Terraform)

The LUN-based symlink is always available at:
```
/dev/disk/azure/scsi1/lun10 → ../../sda (or sdb)
```

Our udev rule creates a cleaner path directly in `/dev/`.

## Troubleshooting

### Symlink Not Created

1. **Check udev rules exist:**
   ```bash
   cat /etc/udev/rules.d/99-azure-data-disk.rules
   ```

2. **Reload udev:**
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger --subsystem-match=block
   ```

3. **Check device attributes:**
   ```bash
   udevadm info --query=all --name=/dev/sda
   udevadm info --query=all --name=/dev/sdb
   ```

4. **Verify LUN 10 exists:**
   ```bash
   ls -la /dev/disk/azure/scsi1/
   ```

### Symlink Points to Wrong Device

If the symlink points to the wrong device (OS disk instead of data disk):

1. **Check disk sizes:**
   ```bash
   lsblk -o NAME,SIZE,TYPE
   ```

2. **Verify LUN mapping:**
   ```bash
   ls -la /dev/disk/azure/scsi1/
   ```

3. **Check Terraform LUN configuration:**
   ```bash
   grep -A 5 "azurerm_virtual_machine_data_disk_attachment" main.tf
   ```

   Should show: `lun = "10"`

### Symlink Disappears After Reboot

Udev rules should persist, but if not:

1. **Verify rules file exists:**
   ```bash
   ls -la /etc/udev/rules.d/99-azure-data-disk.rules
   ```

2. **Check udev service is running:**
   ```bash
   systemctl status systemd-udevd
   ```

3. **Re-run setup script:**
   ```bash
   sudo /tmp/setup-azure-disk-udev.sh
   ```

## Best Practices

### ✅ DO

- **Always use `/dev/azure-data`** for Ceph OSD operations
- **Test after every reboot** to ensure symlinks persist
- **Document device mappings** in your infrastructure docs
- **Use the same path** across all hosts for consistency

### ❌ DON'T

- **Don't use `/dev/sda` or `/dev/sdb`** directly in Ceph configs
- **Don't assume device names** are stable without udev rules
- **Don't skip verification** after setup

## Adding More Data Disks

If you add more data disks for additional Ceph OSDs:

1. **Attach at different LUNs** (e.g., LUN 11, LUN 12)
2. **Create additional udev rules** with different names:
   - LUN 11 → `/dev/azure-data2`
   - LUN 12 → `/dev/azure-data3`

3. **Update the udev script** to handle multiple LUNs:

```bash
# Example for multiple disks
cat > /etc/udev/rules.d/99-azure-data-disk.rules <<'EOF'
# LUN 10 - First data disk (1TB)
ENV{ID_PATH}=="*-lun-10", SYMLINK+="azure-data"

# LUN 11 - Second data disk
ENV{ID_PATH}=="*-lun-11", SYMLINK+="azure-data2"

# LUN 12 - Third data disk
ENV{ID_PATH}=="*-lun-12", SYMLINK+="azure-data3"
EOF
```

## Related Documentation

- [README.md](README.md) - Main infrastructure documentation
- [NESTED-VM-NETWORKING.md](NESTED-VM-NETWORKING.md) - Network setup
- [GETTING-STARTED.md](GETTING-STARTED.md) - Deployment guide

## Summary

✅ **Problem Solved**: Inconsistent device names across Azure VMs  
✅ **Solution**: Udev rules create stable `/dev/azure-data` symlinks  
✅ **Ceph Ready**: Use `/dev/azure-data` for all OSD operations  
✅ **Persistent**: Symlinks survive reboots and VM recreations  

All hosts now have a consistent device path for Ceph configuration! 🎉
