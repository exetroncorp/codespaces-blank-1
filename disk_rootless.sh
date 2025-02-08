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
ANSWER_FILE="alpine-answers"  # preconfigured answer file

# === PREPARE THE IMAGE FILE (no sudo, rootless) ===
echo "Creating raw disk image '$DISK_IMAGE' of size $DISK_SIZE..."
qemu-img create -f raw "$DISK_IMAGE" "$DISK_SIZE"

# Download the Alpine ISO if not present
if [ ! -f "$ALPINE_ISO" ]; then
    echo "Downloading Alpine ISO..."
    wget -O "$ALPINE_ISO" "$ISO_URL"
fi

# Verify that the answer file exists
if [ ! -f "$ANSWER_FILE" ]; then
    echo "Answer file '$ANSWER_FILE' not found!"
    echo "Please generate it (for example, by running: setup-alpine -c $ANSWER_FILE) and edit as needed."
    exit 1
fi

echo "Launching QEMU and performing unattended Alpine installation using answer file '$ANSWER_FILE'..."
expect << EOF
  # Enable verbose debugging and increase timeout
  exp_internal 1
  set timeout 300

  # Spawn QEMU using the raw disk image and the Alpine ISO
  spawn qemu-system-x86_64 \
        -m 512 \
        -nic user \
        -drive file=$DISK_IMAGE,format=raw,if=virtio \
        -cdrom $ALPINE_ISO \
        -boot d \
        -nographic

  # Wait for either a "login:" prompt or a shell prompt (# or $)
  expect {
      -re "(login:|[#\$] )" {
          # If "login:" appears, send "root"
          if {[string match "*login:" $expect_out(buffer)]} {
              send "root\r"
          }
      }
      timeout { puts "Timed out waiting for login or shell prompt"; exit 1 }
  }

  # Ensure we have a shell prompt
  expect {
      -re "[#\$] " { }
      timeout { puts "Timed out waiting for shell prompt"; exit 1 }
  }

  # Run setup-alpine using the answer file to drive an unattended installation.
  # (The answer file should be available in the same working directory.)
  send "setup-alpine -f ${ANSWER_FILE}\r"

  # Wait for the installation to complete – Alpine typically powers off when finished.
  expect {
      -re "poweroff" { send_user "\nInstallation complete. QEMU will now power off.\n" }
      timeout { send_user "\nTimed out waiting for installation to complete; consider increasing timeout.\n" }
  }
EOF

echo "Done! The disk image '$DISK_IMAGE' now contains a preinstalled Alpine Linux."
echo "You can later boot it (still without KVM) using, for example:"
echo "  qemu-system-x86_64 -drive file=${DISK_IMAGE},format=raw -m 512 -nic user -nographic"
