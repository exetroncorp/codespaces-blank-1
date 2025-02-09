#!/usr/bin/sh
# qemu-system-x86_64 -m 512 -nic user -boot d -cdrom alpine-standard-3.21.2-x86_64.iso -hda alpine.qcow2 -nographic
qemu-system-x86_64 -m 512 -nic user -hda alpine.qcow2 -nographic


qemu-system-x86_64 -m 512 -nic user -hda alpine.qcow2  -netdev socket,id=net0,backend=pasta  -device virtio-net-pci,netdev=net0  -nographic

qemu-system-x86_64 -m 512  -hda alpine.qcow2 -nographic -net socket,fd=5 -net nic,model=virtio
qrap -m 512  -nic user -hda alpine.qcow2 -nographic -net socket,fd=5 -net nic,model=virtio
qrap -m 512 -nic user -boot d -cdrom alpine-standard-3.21.2-x86_64.iso -hda alpine.qcow2 -nographic -net socket,fd=5 -net nic,model=virtio
qrap 5 kvm -m 512 -nic user -boot d -cdrom alpine-standard-3.21.2-x86_64.iso -hda alpine.qcow2 -nographic -net socket,fd=5 -net nic,model=virtio
qrap 5 kvm -m 512 -nic user -hda alpine.qcow2 -nographic -net socket,fd=5 -net nic,model=virtio

qrap 5 kvm -m 2048 -nic user,model=virtio  -smp 3 -cpu qemu64 -accel tcg,thread=multi -net socket,fd=5 -net nic,model=virtio  -drive file=alpine.raw,if=virtio,format=raw -nographic

qemu-system-x86_64 -m 512 -nic user,model=virtio  -smp 2 -cpu qemu64 -accel tcg,thread=multi -net socket,fd=5 -net nic,model=virtio  -drive file=alpine.qcow2,if=virtio,format=qcow2 -nographic

qemu-system-x86_64 -m 1024 -nic user,model=virtio  -smp 4 -cpu qemu64 -accel tcg,thread=multi -net socket,fd=5 -net nic,model=virtio  -drive file=alpine.qcow2,if=virtio,format=qcow2 -nographic



