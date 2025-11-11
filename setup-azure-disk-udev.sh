#!/bin/bash
# Create consistent device names for Azure data disks using udev rules
# This ensures Ceph can use the same device path across all hosts

set -e

echo "Setting up consistent Azure disk naming for Ceph..."

# Create udev rule for Azure data disk at LUN 10
# This rule is based on the output of `udevadm info` and should be robust.
cat > /etc/udev/rules.d/99-azure-data-disk.rules <<'EOF'
# Azure Data Disk at LUN 10 - consistent naming for Ceph
# This creates /dev/azure-data as a stable symlink.

# Match the disk by its parent SCSI device's kernel name, which includes the LUN.
SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="sd*", SUBSYSTEMS=="scsi", KERNELS=="*:*:*:10", ATTRS{vendor}=="Msft    ", ATTRS{model}=="Virtual Disk    ", SYMLINK+="azure-data", OPTIONS+="string_escape=replace"

# Also create partition symlinks
SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", KERNEL=="sd*[0-9]", SUBSYSTEMS=="scsi", KERNELS=="*:*:*:10", SYMLINK+="azure-data-part%n", OPTIONS+="string_escape=replace"
EOF

echo "Created udev rules at /etc/udev/rules.d/99-azure-data-disk.rules"
cat /etc/udev/rules.d/99-azure-data-disk.rules

# Reload udev rules and wait for them to be applied.
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger --subsystem-match=block
echo "Waiting for udev to settle..."
udevadm settle

# Verify the symlink was created
echo ""
echo "Verifying symlink creation..."
if [ -L /dev/azure-data ]; then
    REAL_DEVICE=$(readlink -f /dev/azure-data)
    echo "✓ SUCCESS: /dev/azure-data -> $REAL_DEVICE"
    ls -la /dev/azure-data*
    echo ""
    echo "Disk information:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT $REAL_DEVICE
else
    echo "✗ ERROR: /dev/azure-data symlink not created"
    echo ""
    echo "Available disk paths in /dev/disk/by-id/:"
    ls -la /dev/disk/by-id/
    exit 1
fi

echo ""
echo "Setup complete! You can now use /dev/azure-data for Ceph OSD setup."
echo "This device path will be consistent across all hosts."
