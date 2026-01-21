#!/bin/bash
#
# Create Ubuntu autoinstall ISO
# This script embeds the autoinstall configuration into an Ubuntu Server ISO
#
# Usage: ./create-autoinstall-iso.sh <ubuntu-server.iso> [output.iso]
#
# Requirements:
#   - xorriso
#   - 7z (p7zip)
#   - Linux or macOS with bash
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ISO="${1:-}"
OUTPUT_ISO="${2:-ubuntu-autoinstall.iso}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check arguments
if [ -z "$SOURCE_ISO" ]; then
    echo "Usage: $0 <ubuntu-server.iso> [output.iso]"
    echo ""
    echo "Example:"
    echo "  $0 ubuntu-24.04-live-server-amd64.iso"
    echo "  $0 ubuntu-24.04-live-server-amd64.iso my-autoinstall.iso"
    exit 1
fi

[ -f "$SOURCE_ISO" ] || error "Source ISO not found: $SOURCE_ISO"

# Check dependencies
check_command() {
    if ! command -v "$1" &> /dev/null; then
        error "$1 is required but not installed. Install it with: $2"
    fi
}

check_command xorriso "brew install xorriso (macOS) or apt install xorriso (Ubuntu)"
check_command 7z "brew install p7zip (macOS) or apt install p7zip-full (Ubuntu)"

# Check for autoinstall files
USER_DATA="$SCRIPT_DIR/user-data"
META_DATA="$SCRIPT_DIR/meta-data"

[ -f "$USER_DATA" ] || error "user-data not found at $USER_DATA"
[ -f "$META_DATA" ] || error "meta-data not found at $META_DATA"

# Create temporary working directory
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

info "Extracting ISO to $WORK_DIR..."
7z x -o"$WORK_DIR" "$SOURCE_ISO" > /dev/null

# Remove Windows-specific files that aren't needed
rm -rf "$WORK_DIR/[BOOT]" 2>/dev/null || true

# Create nocloud directory for autoinstall (server directory for cloud-init)
NOCLOUD_DIR="$WORK_DIR/server"
mkdir -p "$NOCLOUD_DIR"

info "Copying autoinstall configuration..."
cp "$USER_DATA" "$NOCLOUD_DIR/user-data"
cp "$META_DATA" "$NOCLOUD_DIR/meta-data"

# Modify GRUB configuration to add autoinstall parameter
GRUB_CFG="$WORK_DIR/boot/grub/grub.cfg"
if [ -f "$GRUB_CFG" ]; then
    info "Modifying GRUB configuration..."
    cat > "$GRUB_CFG" << 'GRUBEOF'
set timeout=3
loadfont unicode
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Autoinstall Ubuntu Server" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/server/ ---
    initrd  /casper/initrd
}
menuentry "Install Ubuntu Server (Interactive)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz ---
    initrd  /casper/initrd
}
GRUBEOF
fi

info "Creating new ISO: $OUTPUT_ISO..."

# Extract boot parameters from original ISO
info "Extracting boot configuration from source ISO..."
BOOT_PARAMS=$(xorriso -indev "$SOURCE_ISO" -report_el_torito as_mkisofs 2>&1 | grep -E "^-|^--")

# Extract MBR (first 432 bytes) from original ISO
MBR_IMG="$WORK_DIR/boot.mbr"
dd if="$SOURCE_ISO" bs=1 count=432 of="$MBR_IMG" 2>/dev/null

# Extract EFI partition image from the original ISO
# The EFI partition is appended to the ISO, we need to extract it
info "Extracting EFI partition..."
EFI_IMG="$WORK_DIR/efi.img"

# Get the EFI partition offset and size from the original ISO
EFI_START=$(xorriso -indev "$SOURCE_ISO" -report_el_torito as_mkisofs 2>&1 | grep "append_partition 2" | sed -n 's/.*local_fs:\([0-9]*\)d-.*/\1/p')
EFI_END=$(xorriso -indev "$SOURCE_ISO" -report_el_torito as_mkisofs 2>&1 | grep "append_partition 2" | sed -n 's/.*local_fs:[0-9]*d-\([0-9]*\)d.*/\1/p')

if [ -n "$EFI_START" ] && [ -n "$EFI_END" ]; then
    EFI_SIZE=$((EFI_END - EFI_START + 1))
    dd if="$SOURCE_ISO" bs=512 skip="$EFI_START" count="$EFI_SIZE" of="$EFI_IMG" 2>/dev/null
else
    # Alternative: extract using sector info from report
    EFI_INFO=$(xorriso -indev "$SOURCE_ISO" -report_el_torito as_mkisofs 2>&1 | grep "interval:appended_partition_2_start")
    EFI_START_SECTOR=$(echo "$EFI_INFO" | sed -n 's/.*start_\([0-9]*\)s.*/\1/p')
    EFI_SIZE_SECTORS=$(echo "$EFI_INFO" | sed -n 's/.*size_\([0-9]*\)d.*/\1/p')
    if [ -n "$EFI_START_SECTOR" ] && [ -n "$EFI_SIZE_SECTORS" ]; then
        dd if="$SOURCE_ISO" bs=512 skip="$EFI_START_SECTOR" count="$EFI_SIZE_SECTORS" of="$EFI_IMG" 2>/dev/null
    else
        error "Could not extract EFI partition information from source ISO"
    fi
fi

[ -f "$EFI_IMG" ] && [ -s "$EFI_IMG" ] || error "Failed to extract EFI image"
info "EFI partition extracted: $(ls -lh "$EFI_IMG" | awk '{print $5}')"

# Create the new ISO using xorriso
# This creates a hybrid ISO that boots on both BIOS and UEFI systems
xorriso -as mkisofs \
    -r \
    -V "UBUNTU_AUTOINSTALL" \
    -o "$OUTPUT_ISO" \
    -J -joliet-long \
    -iso-level 3 \
    --grub2-mbr "$MBR_IMG" \
    --mbr-force-bootable \
    -partition_offset 16 \
    -appended_part_as_gpt \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$EFI_IMG" \
    -c '/boot.catalog' \
    -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
    -no-emul-boot \
    "$WORK_DIR"

info "Done! Created: $OUTPUT_ISO"
ls -lh "$OUTPUT_ISO"
echo ""
echo "To use this ISO:"
echo "  1. Boot from the ISO (USB or VM)"
echo "  2. Select 'Autoinstall Ubuntu Server' from the menu"
echo "  3. Installation will proceed automatically"
echo "  4. System will reboot when complete"
echo ""
echo "Default credentials:"
echo "  Username: ubuntu"
echo "  Password: 1"

