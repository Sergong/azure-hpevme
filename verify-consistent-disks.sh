#!/bin/bash
# Verification script for consistent disk naming across all hosts

echo "=========================================="
echo "Verifying Consistent Disk Naming"
echo "=========================================="
echo ""

echo "1. Checking /dev/azure-data symlinks:"
ansible azure_vms -m shell -a "ls -la /dev/azure-data*"

echo ""
echo "2. Verifying symlink targets:"
ansible azure_vms -m shell -a "readlink -f /dev/azure-data"

echo ""
echo "3. Checking disk information:"
ansible azure_vms -m shell -a "lsblk -o NAME,SIZE,TYPE,MOUNTPOINT \$(readlink -f /dev/azure-data)"

echo ""
echo "4. Verifying LUN mapping:"
ansible azure_vms -m shell -a "ls -la /dev/disk/azure/scsi1/lun10"

echo ""
echo "5. Checking udev rules:"
ansible azure_vms -m shell -a "test -f /etc/udev/rules.d/99-azure-data-disk.rules && echo 'udev rules exist' || echo 'udev rules missing'"

echo ""
echo "=========================================="
echo "Summary:"
echo "=========================================="
echo "✓ Both hosts should have /dev/azure-data symlink"
echo "✓ Symlinks may point to different devices (sda vs sdb)"
echo "✓ Both should point to 1TB disks at LUN 10"
echo "✓ Use /dev/azure-data for Ceph configuration"
echo ""
echo "For Ceph OSD creation, use:"
echo "  ceph-volume lvm create --data /dev/azure-data"
echo ""
