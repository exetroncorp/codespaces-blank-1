#!/bin/bash
set -euo pipefail

# ----- CONFIGURATION -----
IMAGE="disk.raw"
IMG_SIZE="2G"
MOUNT_DIR="/tmp/alpine_disk_mount"
ALPINE_VERSION="3.21.2"
ALPINE_VERSION_MAIN="3.21"
ARCH="x86_64"

# URLs for Alpine netboot kernel and initramfs and the minirootfs tarball.
# (You may adjust these URLs as needed for your desired Alpine release.)
KERNEL_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ARCH}/netboot/vmlinuz-lts"
INITRD_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ARCH}/netboot/initramfs-lts"
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION}-${ARCH}.tar.gz"

# Extlinux configuration file contents.
EXTLINUX_CONF=$(cat << 'EOF'
DEFAULT alpine
LABEL alpine
  MENU LABEL Alpine Linux
  KERNEL /boot/vmlinuz-lts
  APPEND initrd=/boot/initramfs-lts root=/dev/sda1 rw
EOF
)

# ----- INSTALL PREREQUISITES -----
echo "Installing prerequisite packages..."
sudo apt update
sudo apt install -y qemu-system qemu-utils e2fsprogs parted syslinux-common extlinux wget expect flex ninja 

# ----- CREATE RAW DISK IMAGE -----
echo "Creating raw disk image ($IMAGE) of size $IMG_SIZE..."
qemu-img create -f raw "$IMAGE" "$IMG_SIZE"

# ----- SET UP LOOP DEVICE -----
echo "Setting up loop device..."
# -P makes kernel re-read partition table and creates partition devices (e.g. /dev/loop0p1)
LOOP_DEVICE=$(sudo losetup --find --show -P "$IMAGE")
echo "Loop device: $LOOP_DEVICE"

# ----- PARTITION THE IMAGE -----
echo "Partitioning the disk image..."
sudo parted -s "$LOOP_DEVICE" mklabel msdos
# Create one primary partition from 1MiB to the end
sudo parted -s "$LOOP_DEVICE" mkpart primary ext4 1MiB 100%
# Tell the kernel to re-read the partition table
sudo partprobe "$LOOP_DEVICE"

# Determine partition name; on many systems it will be like ${LOOP_DEVICE}p1
PARTITION="${LOOP_DEVICE}p1"
if [ ! -e "$PARTITION" ]; then
    # Fallback for systems that append nothing (e.g. /dev/loop0 instead of /dev/loop0p1)
    PARTITION="${LOOP_DEVICE}"
fi
echo "Partition device: $PARTITION"

# ----- FORMAT THE PARTITION -----
echo "Formatting partition as ext4..."
sudo mkfs.ext4 -F "$PARTITION"

# ----- MOUNT THE PARTITION -----
echo "Mounting partition to $MOUNT_DIR..."
sudo mkdir -p "$MOUNT_DIR"
sudo mount "$PARTITION" "$MOUNT_DIR"

# ----- DOWNLOAD ALPINE FILES -----
echo "Downloading Alpine kernel, initramfs, and minirootfs..."
cd /tmp
[ -f vmlinuz-lts ] || wget -O vmlinuz-lts "$KERNEL_URL"
[ -f initramfs-lts ] || wget -O initramfs-lts "$INITRD_URL"
[ -f alpine-minirootfs.tar.gz ] || wget -O alpine-minirootfs.tar.gz "$MINIROOTFS_URL"

# ----- EXTRACT MINIROOTFS -----
echo "Extracting Alpine minirootfs into the image..."
sudo tar -xzf alpine-minirootfs.tar.gz -C "$MOUNT_DIR"

# ----- SET UP BOOT DIRECTORY & COPY KERNEL/INITRAMFS -----
echo "Setting up /boot directory..."
sudo mkdir -p "$MOUNT_DIR/boot"
sudo cp vmlinuz-lts initramfs-lts "$MOUNT_DIR/boot/"

# ----- INSTALL EXTLINUX BOOTLOADER -----
echo "Installing extlinux bootloader..."
sudo mkdir -p "$MOUNT_DIR/boot/extlinux"
# Write extlinux configuration
echo "$EXTLINUX_CONF" | sudo tee "$MOUNT_DIR/boot/extlinux/extlinux.conf" >/dev/null

# Install extlinux into the boot directory.
sudo extlinux --install "$MOUNT_DIR/boot/extlinux"

# Write MBR from syslinux common files.
# On Ubuntu, the MBR file is often at /usr/lib/syslinux/mbr.bin or /usr/lib/syslinux/modules/bios/mbr.bin.
if [ -f /usr/lib/syslinux/mbr.bin ]; then
    MBR_FILE="/usr/lib/syslinux/mbr.bin"
elif [ -f /usr/lib/syslinux/modules/bios/mbr.bin ]; then
    MBR_FILE="/usr/lib/syslinux/modules/bios/mbr.bin"
else
    echo "Could not locate mbr.bin file; please install syslinux-common."
    exit 1
fi
echo "Writing MBR using $MBR_FILE..."
sudo dd if="$MBR_FILE" of="$LOOP_DEVICE" bs=440 count=1 conv=notrunc

# ----- CLEAN UP -----
echo "Unmounting partition and detaching loop device..."
sudo umount "$MOUNT_DIR"
sudo losetup -d "$LOOP_DEVICE"
rm -rf "$MOUNT_DIR"

echo "Done! The disk image '$IMAGE' is ready."
echo "You can boot it in QEMU (without KVM) using, for example:"
echo "  qemu-system-x86_64 -drive file=$IMAGE,format=raw -m 512"
