How to compile the linux kernel, launch it as a process and boot into Alpine linux

Command + Shift + 5

Host -> Docker GCC -> UML w/ Alpine 

# get docker for compiling
foo@host:~$ docker pull gcc
# launch new container
foo@host:~$ docker run --privileged --name gcc -it gcc /bin/bash
# Attatch to existing container
foo@host:~$ docker exec -it gcc /bin/bash

# Install deps
cd ~
apt update
apt-get -y install build-essential flex bison xz-utils wget ca-certificates linux-headers-amd64 bc  slirp kmod vim flex
and configure the linux kernel
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.68.tar.xz
tar -xf linux-6.6.68.tar.xz  # decompress
cd linux-6.6.68.tar.xz 
make mrproper # clean artifacts
make defconfig ARCH=um # set a bunch of default configurations (eg: ext4, initramfs etc..) essential
make menuconfig ARCH=um # add your own custom config (optional)

UML Menu (optional)
General setup
 - Initial RAM filesystem and RAM disk support (on by default)
Networking support (enable this to get the submenu to show up): (on by default)
  - Networking options:
    - TCP/IP Networking (on by default)
UML Network devices (hidden):
 - Virtual network device (on by default)
 - SLiRP transport (on by default)
Enable loadable module support (on by default)
File Systems
  - The extended 4 (ext4) filesystem (on by default)
=> Save and exit

# create and mount the filesystem
foo@gcc:~/linux-5.12.4$ rm -rf ./root_fs 
foo@gcc:~/linux-5.12.4$ dd if=/dev/zero of=root_fs bs=1M count=1024
foo@gcc:~/linux-5.12.4$ mkfs.ext4 -L ALPINE_ROOT root_fs
foo@gcc:~/linux-5.12.4$ mkdir /mnt/uml
foo@gcc:~/linux-5.12.4$ mount -t ext4 -o loop root_fs /mnt/uml
foo@gcc:~/linux-5.12.4$ lsblk | grep loop0 # optional 
foo@gcc:~/linux-5.12.4$ mount | grep uml # optional

# Download and install the Alpine linux filesystem and tools
foo@gcc:~/linux-5.12.4$ curl -LO https://dl-cdn.alpinelinux.org/alpine/v3.21/main/x86_64/apk-tools-static-2.14.6-r2.apk
# add package manager to UML
foo@gcc:~/linux-5.12.4$ tar -xvf apk-tools-static-*.apk -C /mnt/uml
# install Alpine filesystem
foo@gcc:~/linux-5.12.4$  /mnt/uml/sbin/apk.static --repository http://dl-cdn.alpinelinux.org/alpine/v3.13/main/ --update-cache --allow-untrusted --root  /mnt/uml --initdb add alpine-base 
foo@gcc:~/linux-5.12.4$ ls -lah /mnt/uml

# Build the linux kernel and add kernel modules to filesystem
foo@gcc:~/linux-5.12.4$ make -j$(nproc) ARCH=um # compile linux
foo@gcc:~/linux-5.12.4$ ls -lah 
foo@gcc:~/linux-5.12.4$ make modules ARCH=um SUBARCH=x86_64 # compile the kernel modules
foo@gcc:~/linux-5.12.4$ make modules_install INSTALL_MOD_PATH=/mnt/uml ARCH=um SUBARCH=x86_64 # install the kernel modules to the filesystem

# update the filesystem table
echo "LABEL=ALPINE_ROOT / ext4 defaults 0 0" > /mnt/uml/etc/fstab
echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" > /mnt/uml/etc/apk/repositories
echo "https://dl-cdn.alpinelinux.org/alpine/edge/community" >> /mnt/uml/etc/apk/repositories
echo "nameserver 8.8.8.8" > /mnt/uml/etc/resolv.conf
# mount the filesystem before starting the kernel
umount /mnt/uml
# on host
export TMPDIR=/tmp
slirp > /dev/null 2>&1 &
bg %1
./linux ubda=root_fs rw mem=64M init=/bin/sh rootfstype=ext4 eth0=slirp TERM=linux quiet

# configure User Mode Linux networking etc
PS1="[\u@uml:\w ] $ "
mount -t proc proc proc/
mount -t sysfs sys sys/
ifconfig eth0 10.0.2.14 netmask 255.255.255.240 broadcast 10.0.2.15
route add default gw 10.0.2.2
nslookup google.com
apk update
apk search curl
apk add curl
curl https://www.reddit.com/r/worldnews.json -H "User-agent: uml"
halt -f # exit gracefully

# close network proxy on host
foo@gcc:~/linux-5.12.4$ kill %1 # close slirp

# Inside UML
[root@uml:/ ] $ ping -c 4 8.8.8.8  # Test raw IP connectivity