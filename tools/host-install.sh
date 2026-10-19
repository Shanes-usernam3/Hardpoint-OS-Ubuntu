#!/usr/bin/env bash
# CI helper: install a HardPoint OS ISO onto a qcow2 disk without the GUI installer,
# doing what the Calamares installer does (partition, unpack, fstab, user, bootloader),
# so the VM test can boot and screenshot the installed system.
#   sudo host-install.sh <iso> <disk.qcow2> <user> <password>
set -euo pipefail
ISO="$(realpath "$1")" DISK="$(realpath "$2")" USER_NAME="$3" PASS="$4"
W="$(mktemp -d)"
NBD=/dev/nbd0
log() { printf '[host-install] %s\n' "$*"; }
cleanup() {
    set +e
    for m in "$W/t/boot/efi" "$W/t/dev/pts" "$W/t/dev" "$W/t/proc" "$W/t/sys" "$W/t/sys/firmware/efi/efivars" "$W/t/run" "$W/t"; do
        mountpoint -q "$m" && umount -l "$m"
    done
    mountpoint -q "$W/iso" && umount "$W/iso"
    qemu-nbd -d "$NBD" >/dev/null 2>&1
}
trap cleanup EXIT

modprobe nbd max_part=8
qemu-nbd -c "$NBD" "$DISK"
sleep 2
log "Partitioning (EFI + root)"
sgdisk -Z "$NBD" >/dev/null
sgdisk -n1:1M:+512M -t1:EF00 -c1:EFI -n2:0:0 -t2:8304 -c2:root "$NBD" >/dev/null
partprobe "$NBD"; sleep 2
mkfs.vfat -F32 -n EFI "${NBD}p1" >/dev/null
mkfs.ext4 -q -F -L hardpoint "${NBD}p2"

mkdir -p "$W/iso" "$W/t"
mount -o loop,ro "$ISO" "$W/iso"
mount "${NBD}p2" "$W/t"
log "Unpacking the system"
unsquashfs -q -f -d "$W/t" "$W/iso/casper/filesystem.squashfs"
mkdir -p "$W/t/boot/efi"
mount "${NBD}p1" "$W/t/boot/efi"
# Like Calamares' kerncopy step: the live kernel goes into /boot if the image left it out
KVER="$(ls "$W/t/lib/modules" | sort -V | tail -1)"
[[ -f $W/t/boot/vmlinuz-$KVER ]] || cp "$W/iso/casper/vmlinuz" "$W/t/boot/vmlinuz-$KVER"

cat > "$W/t/etc/fstab" <<EOF
UUID=$(blkid -s UUID -o value "${NBD}p2") / ext4 defaults 0 1
UUID=$(blkid -s UUID -o value "${NBD}p1") /boot/efi vfat umask=0077 0 1
EOF
echo hardpoint-test > "$W/t/etc/hostname"
printf '127.0.0.1 localhost\n127.0.1.1 hardpoint-test\n' > "$W/t/etc/hosts"
: > "$W/t/etc/machine-id"

for d in dev dev/pts proc sys run; do mount --bind "/$d" "$W/t/$d"; done
cat > "$W/t/tmp/inst.sh" <<EOF
set -e
export DEBIAN_FRONTEND=noninteractive
# What the installer removes from the installed system
dpkg --purge casper calamares calamares-settings-kubuntu calamares-settings-ubuntu-common calamares-settings-ubuntu-common-data \
    calamares-data kubuntu-installer-prompt >/dev/null 2>&1 || true
useradd -m -s /bin/bash -c "HardPoint Test" -G adm,cdrom,dip,lpadmin,plugdev,sudo "$USER_NAME"
echo "$USER_NAME:$PASS" | chpasswd
ln -sf /usr/share/zoneinfo/America/Edmonton /etc/localtime
echo 'LANG=en_US.UTF-8' > /etc/default/locale
update-initramfs -c -k "$KVER" >/dev/null 2>&1 || update-initramfs -u -k "$KVER" >/dev/null
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --removable --no-nvram >/dev/null
update-grub >/dev/null 2>&1
EOF
log "Configuring (user, initramfs, bootloader)"
chroot "$W/t" /usr/bin/env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 bash /tmp/inst.sh
rm -f "$W/t/tmp/inst.sh"
log "Installed: $(grep -h PRETTY_NAME "$W/t/etc/os-release"), kernel $KVER"
