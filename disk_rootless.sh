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
ANSWER_FILE="alpine-answers"   # preconfigured answer file (must exist in the current directory)

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
    echo "Please generate it (e.g. run: setup-alpine -c $ANSWER_FILE) and edit as needed."
    exit 1
fi

# Get the absolute path of the current directory.
HOST_DIR=$(pwd)

echo "Launching QEMU and automating Alpine installation using answer file '$ANSWER_FILE'..."

expect << EOF
  # Enable verbose debugging and set a long timeout (300 seconds)
  exp_internal 1
  set timeout 300
  exp_internal 1
  log_user 1


  # Spawn QEMU with the following options:
  # - Use the raw disk image and Alpine ISO.
  # - Boot with -nographic.
  # - Share the current host directory (HOST_DIR) into the guest under the tag "hostshare".
  spawn qemu-system-x86_64 \
      -m 512 \
      -nic user \
      -drive file=${DISK_IMAGE},format=raw,if=virtio \
      -cdrom ${ALPINE_ISO} \
      -boot d \
      -nographic \
      -virtfs local,path=${HOST_DIR},mount_tag=hostshare,security_model=none,readonly

  # Wait for either a "login:" prompt or a shell prompt (# or $)
expect {
    -re "localhost login:" { send "root\r" }
}

expect {
    -re "localhost:~# " { }
    timeout { puts "Timed out waiting for shell prompt"; exit 1 }
}



  # Ensure a shell prompt is present
  expect {
      -re "[#\$] " { }
      timeout { puts "Timed out waiting for shell prompt"; exit 1 }
  }

  # Run the unattended installation using the preconfigured answer file.
  # The answer file is accessible inside the guest at "hostshare/alpine-answers".
  send "setup-alpine -f hostshare/${ANSWER_FILE}\r"

  # Wait until the installer outputs "poweroff" (installation complete)
  expect {
      -re "poweroff" { send_user "\nInstallation complete. QEMU will now power off.\n" }
      timeout { send_user "\nTimed out waiting for installation to complete; consider increasing timeout.\n" }
  }
EOF

echo "Done! The disk image '$DISK_IMAGE' now contains a preinstalled Alpine Linux."
echo "You can later boot it (without KVM) using, for example:"
echo "  qemu-system-x86_64 -drive file=${DISK_IMAGE},format=raw -m 512 -nic user -nographic"
