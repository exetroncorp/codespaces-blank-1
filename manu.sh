#!/bin/bash
# apk add qemu qemu-img qemu-system-x86_64 qemu-ui-gtk

# Create the Virtual Machine
# Create a disk image if you want to install Alpine Linux.

qemu-img create -f qcow2 alpine.qcow2 8G

# The following command starts QEMU with the Alpine ISO image as CDROM, the default network configuration, 512MB RAM, the disk image that was created in the previous step, and CDROM as the boot device.

qemu-system-x86_64 -m 512 -nic user -boot d -cdrom alpine-standard-3.21.2-x86_64.iso -hda alpine.qcow2 -nographic

# Tip: Remove option -enable-kvm if your hardware does not support this.
# Log in as root (no password) and run:

# setup-alpine

# Follow the setup-alpine installation steps.

# Run poweroff to shut down the machine.

# Booting the Virtual Machine
# After the installation, QEMU can be started from disk image (-boot c) without CDROM.

qemu-system-x86_64 -m 512 -nic user -hda alpine.qcow2