#!/bin/bash
set -euo pipefail

# === CONFIGURATION ===
# (Adjust these variables as needed)
ALPINE_VERSION_MAIN="3.21"
ALPINE_VERSION="3.21.2"
ARCH="x86_64"
DISK_IMAGE="alpine_disk.raw"
DISK_SIZE="2G"
ALPINE_ISO="alpine-standard-${ALPINE_VERSION}-${ARCH}.iso"
ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION_MAIN}/releases/${ARCH}/${ALPINE_ISO}"


# === PREPARE THE IMAGE FILE (no sudo, rootless) ===
echo "Creating raw disk image '$DISK_IMAGE' of size $DISK_SIZE..."
qemu-img create -f raw "$DISK_IMAGE" "$DISK_SIZE"

# Download the Alpine ISO if not present
if [ ! -f "$ALPINE_ISO" ]; then
    echo "Downloading Alpine ISO..."
    wget -O "$ALPINE_ISO" "$ISO_URL"
fi

# === AUTOMATED INSTALLATION VIA QEMU + EXPECT ===
# This Expect script launches QEMU (without -enable-kvm, so purely in software)
# with the disk image attached as a virtio drive and the Alpine ISO as CDROM.
# It connects the serial port to stdio (-serial stdio -nographic)
# and then sends keystrokes to the guest’s console to run setup-alpine
# and answer its prompts automatically.
#
# The expected conversation is roughly:
#   1. At the login prompt, type "root" (Alpine ISO normally logs you in as root with no password).
#   2. At the shell prompt, type "setup-alpine" and then simulate answers:
#      - Accept default hostname (press Enter)
#      - Accept default keyboard (Enter)
#      - Accept default network interface (Enter)
#      - For IP config, type "dhcp" (Enter)
#      - For root password, type "vagrant" twice (Enter each time)
#      - For timezone, type "UTC" (Enter)
#      - For mirror, press Enter (accept default)
#      - For disk selection, type "vda" (Enter)
#      - For installation mode, type "sys" (Enter)
#      - For bootloader install, type "y" (Enter)
#
# (The actual prompts and timing may vary with Alpine versions; you might need
# to tweak the expect patterns or delays.)
echo "Launching QEMU and automating Alpine installation (this may take several minutes)..."
expect << EOF
  log_user 1
  # Spawn QEMU as an unprivileged user; note: no sudo or mount is used.

spawn qemu-system-x86_64 \
      -m 512 \
      -nic user \
      -drive file=alpine_disk.raw,format=raw,if=virtio \
      -cdrom alpine-standard-3.21.2-x86_64.iso \
      -boot d \
      -nographic

  # Wait for the login prompt; Alpine ISO typically shows "login:" on its serial console.

  expect {
  -re "login:" { send "root\r" }
  -re "# "   { }  ;# already at a shell prompt
  timeout  { puts "Timed out waiting for login prompt"; exit 1 }
  }


  # Wait a little for the shell prompt to appear (the prompt may be something like "ash# ").
  expect {
    -re "# " { }
    timeout { puts "Timed out waiting for shell prompt"; exit 1 }
  }

  # Start the installation process
  send "setup-alpine\r"

  # Now simulate interactive answers.
  # The following expect/send pairs assume prompts that contain a colon ":".
  # You may adjust the regular expressions and responses as needed.
  expect {
    -re "Hostname:" { send "\r" } ;# accept default hostname ("alpine")
    timeout { puts "No hostname prompt found"; exit 1 }
  }
  expect {
    -re "Keyboard" { send "\r" } ;# accept default keyboard layout
    timeout { puts "No keyboard prompt found"; exit 1 }
  }
  expect {
    -re "Network interface" { send "\r" } ;# accept default (usually "eth0")
    timeout { puts "No network prompt found"; exit 1 }
  }
  expect {
    -re "IP configuration" { send "dhcp\r" } ;# choose DHCP
    timeout { puts "No IP configuration prompt found"; exit 1 }
  }
  # Set root password; Alpine's setup-alpine asks twice.
  expect {
    -re "Enter root password:" { send "vagrant\r" }
    timeout { puts "No root password prompt"; exit 1 }
  }
  expect {
    -re "Enter password again:" { send "vagrant\r" }
    timeout { puts "No confirmation for root password"; exit 1 }
  }
  expect {
    -re "Timezone:" { send "UTC\r" }
    timeout { puts "No timezone prompt"; exit 1 }
  }
  expect {
    -re "Mirror:" { send "\r" } ;# accept default mirror
    timeout { puts "No mirror prompt"; exit 1 }
  }
  expect {
    -re "Disk" { send "vda\r" } ;# select disk device name as seen by Alpine (use "vda" for virtio drive)
    timeout { puts "No disk selection prompt"; exit 1 }
  }
  expect {
    -re "Installation mode" { send "sys\r" } ;# choose sys (install to disk)
    timeout { puts "No installation mode prompt"; exit 1 }
  }
  expect {
    -re "Install bootloader" { send "y\r" } ;# confirm bootloader installation
    timeout { puts "No bootloader prompt"; exit 1 }
  }
  # Allow extra time for installation to complete.
  # (You might see progress messages on the serial console.)
  expect {
    -re "poweroff" { send_user "\nInstallation complete. QEMU will now power off.\n" }
    timeout { send_user "\nTimed out waiting for installation to complete; you may need to adjust delays.\n" }
  }
EOF

echo "Done! The disk image '$DISK_IMAGE' now contains a preinstalled Alpine Linux."
echo "You can later boot it (still without KVM) using, for example:"
echo "  qemu-system-x86_64 -drive file=${DISK_IMAGE},format=raw -m 512 -nic user -nographic"