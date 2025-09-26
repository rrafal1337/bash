#!/bin/bash
set -euo pipefail # Enable strict error checking
set -x            # Enable command tracing

# =============================================================================
# SystemRescueCD USB Creator
# =============================================================================
#
# This script creates bootable USB drive with SystemRescueCD using syslinux.
# It handles partitioning, formatting and file copying automatically.
#
# Features:
# - Creates bootable USB drive
# - Installs syslinux bootloader
# - Copies SystemRescueCD files
# - Handles syslinux compatibility issues
#
# Usage: ./syslinux_for_sysrescd.sh --label LABEL --device /dev/sdX --iso file.iso
#

# Show help message
show_help() {
  cat <<EOF
Usage: ${0} [OPTIONS]

Options:
  --label LABEL    USB drive label (e.g., RESCUE1201)
  --device DEV     Target device (e.g., /dev/sdb)
  --iso FILE      Path to SystemRescueCD ISO file
  --help          Show this help message

Example:
  ${0} --label RESCUE1201 --device /dev/sdb --iso systemrescue-12.01-amd64.iso
EOF
}

# Default values
TARGETLABEL=""
TARGETDEV=""
SOURCEISO=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --label)
    TARGETLABEL="$2"
    shift 2
    ;;
  --device)
    TARGETDEV="$2"
    shift 2
    ;;
  --iso)
    SOURCEISO="$2"
    shift 2
    ;;
  --help)
    show_help
    exit 0
    ;;
  *)
    echo "Error: Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
done

# Validate required arguments
if [[ -z "${TARGETLABEL}" ]]; then
  echo "Error: --label is required"
  show_help
  exit 1
fi

if [[ -z "${TARGETDEV}" ]]; then
  echo "Error: --device is required"
  show_help
  exit 1
fi

if [[ -z "${SOURCEISO}" ]]; then
  echo "Error: --iso is required"
  show_help
  exit 1
fi

# Validate device exists
if [[ ! -b "${TARGETDEV}" ]]; then
  echo "Error: Device ${TARGETDEV} does not exist or is not a block device"
  exit 1
fi

# Validate ISO file exists
if [[ ! -f "${SOURCEISO}" ]]; then
  echo "Error: ISO file ${SOURCEISO} does not exist"
  exit 1
fi

# Confirm with user before proceeding
echo "WARNING: This will erase all data on ${TARGETDEV}"
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled"
  exit 1
fi

# Target partition number
TARGETPART=1

# Clean first 16MB of the device to ensure clean state
echo "Cleaning device header..."
dd if=/dev/zero bs=4M count=4 of="${TARGETDEV}"
sync

# Create partition table and partition
echo "Creating partition..."
parted "${TARGETDEV}" mktable msdos
sync
parted "${TARGETDEV}" mkpart primary fat32 0% 100%
sync

# Format partition with FAT32
echo "Formatting partition..."
mkfs.vfat -n "${TARGETLABEL}" "${TARGETDEV}${TARGETPART}"

# Install syslinux bootloader
echo "Installing syslinux..."
dd conv=notrunc bs=440 count=1 if=/usr/share/syslinux/mbr.bin of="${TARGETDEV}"
parted "${TARGETDEV}" set 1 boot on
sync
syslinux -i "${TARGETDEV}${TARGETPART}"

# Update partition table
echo "Updating partition table..."
partprobe

# Mount filesystems
echo "Mounting filesystems..."
mount "${TARGETDEV}${TARGETPART}" /mnt/usb
mount -o loop "${SOURCEISO}" /mnt/cdrom

# Copy files
echo "Copying SystemRescueCD files..."
cp -r /mnt/cdrom/* /mnt/usb/

# Fix syslinux compatibility
echo "Installing compatible syslinux files..."
cp /usr/share/syslinux/* /mnt/usb/sysresccd/boot/syslinux/
cp /mnt/usb/isolinux/isolinux.cfg /mnt/usb/syslinux.cfg

# Ensure all writes are completed
sync

# Cleanup
echo "Unmounting filesystems..."
umount /mnt/usb
umount /mnt/cdrom

echo "USB drive creation complete!"
echo "You can now safely remove ${TARGETDEV}"
