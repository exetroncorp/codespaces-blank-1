#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
ALPINE_VERSION_MAIN="3.21"
ALPINE_VERSION="3.21.2"
ARCH="x86_64"
DISK_IMAGE="alpine_disk.raw"
DISK_SIZE="2G"
ALPINE_ISO="alpine-standard-${ALPINE_VERSION}-${ARCH}.iso"
ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION_MAIN}/releases/${ARCH}/${ALPINE_ISO}"
ANSWER_FILE="alpine-answers"   # This file must exist in your current directory

# === PREPARE THE IMAGE FILE (no sudo, rootless) ===
echo "Creating raw disk image '$DISK_IMAGE' of size $DISK_SIZE..."
qemu-img create -f raw "$DISK_IMAGE" "$DISK_SIZE"

# Download the Alpine ISO if not present
if [ ! -f "$ALPINE_ISO" ]; then
    echo "Downloading Alpine ISO..."
    wget -O "$ALPINE_ISO" "$ISO_URL"
fi

# Check that the answer file exists
if [ ! -f "$ANSWER_FILE" ]; then
    echo "Answer file '$ANSWER_FILE' not found!"
    echo "Please generate it (e.g., run: setup-alpine -c $ANSWER_FILE) and edit as needed."
    exit 1
fi

# Get the absolute path of the current directory.
HOST_DIR=$(pwd)

qemu-system-x86_64 \
      -m 512 \
      -nic user \
      -drive file=${DISK_IMAGE},format=raw,if=virtio \
      -cdrom ${ALPINE_ISO} \
      -boot d \
      -nographic \
      -virtfs local,path=${HOST_DIR},mount_tag=hostshare,security_model=none,readonly

# echo "Launching QEMU and automating Alpine installation using answer file '$ANSWER_FILE'..."
# expect <<EOF
#   # Enable internal debugging and set timeout
#   exp_internal 1
#   set timeout 300

#   # Spawn QEMU.
#   # The -virtfs option now uses the absolute path from HOST_DIR.
#   spawn qemu-system-x86_64 \
#       -m 512 \
#       -nic user \
#       -drive file=${DISK_IMAGE},format=raw,if=virtio \
#       -cdrom ${ALPINE_ISO} \
#       -boot d \
#       -nographic \
#       -virtfs local,path=${HOST_DIR},mount_tag=hostshare,security_model=none,readonly

#   # Wait for the login prompt.
#   expect {
#       -re "localhost login:" { send "root\r\r" }
#       -re "[#\$] " { }  ;# Already at a shell prompt
#       timeout { puts "Timed out waiting for login prompt"; exit 1 }
#   }

#   # Wait explicitly for a full shell prompt.
#   sleep 1
#   send "\r"
#   expect -re "localhost:~# "

#   # Mount the shared directory inside the guest
#   send "mkdir -p /mnt/hostshare\r"
#   expect -re "localhost:~# "
#   send "mount -t 9p -o trans=virtio hostshare /mnt/hostshare\r"
#   expect -re "localhost:~# "

#   # Run the unattended installation using the preconfigured answer file.
#   # The answer file is accessed inside the guest via the mounted directory.
#   send "setup-alpine -f /mnt/hostshare/${ANSWER_FILE}\r"
#  expect -re "Enter system hostname"
#   send "\r"

#    expect -re "where to store configs"
#    send "\r"

#    send "\r"
#      expect -re "apk cache directory"
#      send "\r"
#           send "\r"
#                send "\r"
#           send "\r"
#                send "\r"
#           send "\r"
#                send "\r"
#           send "\r"
#                send "\r"
#           send "\r"
#                send "\r"
#           send "\r"
#           expect -re "Which disk(s) would you like to use"
#   send "sda/r"
#     expect -re "eeee"
#   # Wait for the installer to signal completion (for example, by outputting "poweroff").
#   expect {
#       -re "poweroff" { send_user "\nInstallation complete. QEMU will now power off.\n" }
#       timeout { send_user "\nTimed out waiting for installation to complete; consider increasing timeout.\n" }
#   }
# EOF

# echo "Done! The disk image '$DISK_IMAGE' now contains a preinstalled Alpine Linux."
# echo "You can later boot it (without KVM) using, for example:"
# echo "  qemu-system-x86_64 -drive file=${DISK_IMAGE},format=raw -m 512 -nic user -nographic"
