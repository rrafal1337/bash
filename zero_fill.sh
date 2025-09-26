#!/bin/bash

# =============================================================================
# Zero Fill Script - Secure Free Space Wiping
# =============================================================================
#
# This script securely wipes free space on a filesystem by filling it with zeros.
# Useful for:
# - Preparing disk images for compression
# - Ensuring deleted data cannot be recovered
# - Improving VM disk space usage
#
# Usage: ./zero_fill.sh [target_directory]
#

# Path to the target mount point (default: current directory)
# ${1:-.} uses parameter expansion to set default value if $1 is not provided
TARGET="${1:-.}"

# Name of the filler file that will be created and then deleted
FILLER_FILE="$TARGET/zero.fill"

echo "Zero-filling free space on: $TARGET"
echo "Creating large zero-filled file. This may take a while..."

# Use dd to fill up free space with zeros:
# if=/dev/zero   - read from zero device (endless stream of zeros)
# of=            - output file
# bs=1M         - use 1MB blocks for better performance
# status=progress - show progress during operation
# || true       - continue even if dd fails (when disk is full)
dd if=/dev/zero of="$FILLER_FILE" bs=1M status=progress || true

# Sync to ensure all pending writes are flushed to disk
sync

# Remove the filler file to reclaim space
# -f flag prevents error messages if file doesn't exist
rm -f "$FILLER_FILE"

# Final sync to ensure removal is complete
sync

echo "Done. Free space wiped with zeros."
