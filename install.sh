#!/bin/bash
###############################################################################
# CHR (MikroTik Cloud Hosted Router) auto-installer for bare-metal / VPS
#
# Author  : mrakbari_ir
# GitHub  : https://github.com/mrakbari_ir
#
# Run this from a Linux rescue system (e.g. Hetzner/OVH rescue mode).
# It downloads a CHR image, patches the RouterOS config so it comes up
# with network + password already set, resizes the disk, and dd's it
# onto the target block device.
#
# !!! THIS SCRIPT WIPES THE TARGET DISK. DOUBLE-CHECK TARGET_DISK BELOW !!!
###############################################################################
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration - EDIT THESE
# ---------------------------------------------------------------------------
CHR_VERSION="7.19.4"
CHR_URL="https://download.mikrotik.com/routeros/${CHR_VERSION}/chr-${CHR_VERSION}.img.zip"
TARGET_DISK="/dev/vda"          # <-- the real disk to overwrite. CHECK with `lsblk` first.
NEW_SIZE_BYTES="1073741824"     # 1 GiB virtual disk size after resize
PASSWORD="${PASSWORD:-$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16)}"  # random unless PASSWORD env is set
WORKDIR="$(mktemp -d /root/chr-install.XXXXXX)"

echo "=============================================================="
echo " CHR installer by mrakbari_ir  (https://github.com/mrakbari_ir)"
echo "=============================================================="
echo "Work directory : $WORKDIR"
echo "Target disk    : $TARGET_DISK"
read -p "Type YES to continue and WIPE $TARGET_DISK: " CONFIRM
[ "$CONFIRM" = "YES" ] || { echo "Aborted."; exit 1; }

cd "$WORKDIR"

cleanup() {
    set +e
    mountpoint -q /mnt && umount /mnt
    qemu-nbd -d /dev/nbd0 >/dev/null 2>&1
}
trap cleanup EXIT

echo "=== Installing dependencies ==="
apt-get update
apt-get install -y qemu-utils pv unzip fdisk util-linux

echo "=== Cleanup any leftover nbd from previous runs ==="
modprobe nbd
qemu-nbd -d /dev/nbd0 2>/dev/null || true
sleep 1

echo "=== Downloading CHR ${CHR_VERSION} ==="
wget -q --show-progress "$CHR_URL" -O chr.img.zip
unzip -o chr.img.zip -d .
IMG_FILE=$(find . -maxdepth 1 -iname '*.img' | head -n 1)
if [ -z "$IMG_FILE" ]; then
    echo "ERROR: no .img file found after unzip. Aborting."
    exit 1
fi
mv "$IMG_FILE" chr.img

echo "=== Converting to qcow2 and resizing ==="
qemu-img convert -O qcow2 chr.img chr.qcow2
qemu-img resize chr.qcow2 "$NEW_SIZE_BYTES"

qemu-nbd -c /dev/nbd0 chr.qcow2
echo "Give some time for qemu-nbd to be ready"
sleep 2
partprobe /dev/nbd0
sleep 5

if [ ! -b /dev/nbd0p2 ]; then
    echo "ERROR: /dev/nbd0p2 does not exist. qemu-nbd probably failed to attach. Aborting."
    exit 1
fi

mount /dev/nbd0p2 /mnt

# ---------------------------------------------------------------------------
# Auto-detect the rescue system's own network interface / IP / gateway,
# so the exact same network config gets baked into RouterOS.
# ---------------------------------------------------------------------------
IFACE=$(ip -4 route list default | awk '{print $5; exit}')
if [ -z "$IFACE" ]; then
    echo "ERROR: Could not auto-detect network interface. Aborting."
    exit 1
fi
echo "Detected interface: $IFACE"

ADDRESS=$(ip -4 addr show "$IFACE" scope global | awk '/inet /{print $2; exit}')
GATEWAY=$(ip -4 route list default | awk '{print $3; exit}')

if [ -z "$ADDRESS" ] || [ -z "$GATEWAY" ]; then
    echo "ERROR: Could not determine ADDRESS ($ADDRESS) or GATEWAY ($GATEWAY). Aborting."
    exit 1
fi
echo "Detected address: $ADDRESS  gateway: $GATEWAY"

mkdir -p /mnt/rw
cat > /mnt/rw/autorun.scr <<EOF
/ip address add address=$ADDRESS interface=[/interface ethernet find where name=ether1]
/ip route add gateway=$GATEWAY
/ip service disable telnet
/user set 0 name=root password=$PASSWORD
/ip dns set servers=1.1.1.1,1.0.0.1
/system note set note="Installed via mrakbari_ir CHR installer - https://github.com/mrakbari_ir" show-at-login=no
EOF

umount /mnt

echo "Magic constant is 65537 (second partition start sector). Verify with fdisk if this ever breaks."
echo "This scary sequence removes second partition on nbd0 and creates a new, bigger one"
echo -e 'd\n2\nn\np\n2\n65537\n\nY\nw\n' | fdisk /dev/nbd0

e2fsck -f -y /dev/nbd0p2 || true
resize2fs /dev/nbd0p2

# Verify filesystem is actually healthy before continuing
if ! e2fsck -fn /dev/nbd0p2; then
    echo "ERROR: filesystem check failed after resize. Aborting before writing image to disk."
    exit 1
fi

sleep 1

echo "Compressing to gzip, this can take several minutes"
mount -t tmpfs tmpfs /mnt
pv /dev/nbd0 | gzip > /mnt/chr-extended.gz
sleep 1

qemu-nbd -d /dev/nbd0 || true
sleep 1

if [ ! -b "$TARGET_DISK" ]; then
    echo "ERROR: TARGET_DISK ($TARGET_DISK) does not exist. Aborting before writing."
    exit 1
fi

echo u > /proc/sysrq-trigger
echo "Warming up sleep"
sleep 1

echo "Writing raw image to $TARGET_DISK, this will take time"
zcat /mnt/chr-extended.gz | pv > "$TARGET_DISK"

echo "=============================================================="
echo " Done. Root password: $PASSWORD"
echo " Installed by mrakbari_ir - https://github.com/mrakbari_ir"
echo "=============================================================="
sleep 5 || true
echo "sync disk"
echo s > /proc/sysrq-trigger
echo "Ok, reboot"
echo b > /proc/sysrq-trigger
