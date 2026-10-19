#!/usr/bin/env bash
# HardPoint OS — ISO build script
#
# Takes the base ISO (config/base.env), verifies it, unpacks the live system,
# adds HardPoint OS (branding, apps, security, dev/IT/gaming software) and packs
# a new bootable ISO. Runs on Ubuntu 24.04 (or the GitHub Actions runner) as root.
#
#   sudo ./build.sh            ISO lands in out/
#   CACHE=/path sudo ./build.sh   reuse a downloaded base ISO
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/base.env
source "$HERE/config/base.env"
OUT="${OUT:-$HERE/out}"
CACHE="${CACHE:-$HERE/cache}"
WORK="${WORK:-/var/tmp/hp-work}"
VERSION="${HP_VERSION:-$HP_BASE_VERSION.$(date +%Y%m%d)}"
ISO_NAME="hardpoint-os-${VERSION}-amd64.iso"

log() { printf '\e[1;35m==>\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33mWARN:\e[0m %s\n' "$*" >&2; }
die() { printf '\e[1;31mERROR:\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root (sudo ./build.sh)."
command -v apt-get >/dev/null || die "Build on Ubuntu/Debian."

log "Installing build tools"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq squashfs-tools xorriso rsync wget ca-certificates initramfs-tools-core fdisk \
    python3-pil python3-numpy librsvg2-bin fonts-inter isomd5sum >/dev/null

# ---------------------------------------------------------------- 1. base ISO
mkdir -p "$CACHE" "$OUT"
BASE="$CACHE/$BASE_ISO"
verify() { echo "$BASE_SHA256  $BASE" | sha256sum -c --status; }
if [[ -f $BASE ]] && verify; then
    log "Using cached $BASE_ISO"
else
    rm -f "$BASE"
    for m in $BASE_MIRRORS; do
        log "Downloading $BASE_ISO from $m"
        if wget -q --show-progress --progress=dot:giga -O "$BASE.part" "$m/$BASE_ISO"; then
            mv "$BASE.part" "$BASE"
            if verify; then break; fi
            # Show what the mirror itself publishes, to tell a bad mirror from a stale pin
            wget -qO- "$m/SHA256SUMS.txt" 2>/dev/null | grep -F "$BASE_ISO" || true
            warn "Checksum mismatch from $m (got $(sha256sum "$BASE" | cut -d' ' -f1))"
            rm -f "$BASE"
        fi
        rm -f "$BASE.part"
    done
    [[ -f $BASE ]] || die "Could not download a verified $BASE_ISO from any mirror."
fi
log "Base ISO verified (sha256 $BASE_SHA256)"

# ---------------------------------------------------------------- 2. unpack
cleanup() {
    set +e
    for m in dev/pts dev proc sys run tmp/hp; do
        mountpoint -q "$WORK/root/$m" && umount -lf "$WORK/root/$m"
    done
    mountpoint -q "$WORK/mnt" && umount -lf "$WORK/mnt"
}
trap cleanup EXIT
cleanup
rm -rf "$WORK"; mkdir -p "$WORK"/{mnt,iso,root}
mount -o loop,ro "$BASE" "$WORK/mnt"

mapfile -t SQUASH < <(cd "$WORK/mnt" && find casper -maxdepth 1 -name '*.squashfs' | sort)
log "Live image layers: ${SQUASH[*]:-none}"
[[ -f $WORK/mnt/casper/filesystem.squashfs ]] || die "casper/filesystem.squashfs not found (layout: ${SQUASH[*]}). The base ISO layout changed — update build.sh."
((${#SQUASH[@]} == 1)) || warn "Extra squashfs layers present; only filesystem.squashfs is customised."

log "Copying ISO boot files"
rsync -a --exclude=casper/filesystem.squashfs "$WORK/mnt/" "$WORK/iso/"
log "Unpacking the live system (takes a few minutes)"
unsquashfs -q -f -d "$WORK/root" "$WORK/mnt/casper/filesystem.squashfs"

INSTALLER=unknown
[[ -d $WORK/root/usr/lib/ubiquity ]] && INSTALLER=ubiquity
[[ -f $WORK/root/etc/calamares/settings.conf ]] && INSTALLER=calamares
compgen -G "$WORK/root/usr/share/applications/*install*.desktop" >/dev/null && \
    log "Installer launchers: $(cd "$WORK/root/usr/share/applications" && ls ./*install*.desktop | tr '\n' ' ')"
log "Installer detected: $INSTALLER"

# ---------------------------------------------------------------- 3. hardpoint-os package
# CI passes a prebuilt package in hp-pkg/ (the same one published as an update);
# a local build makes its own.
mkdir -p "$WORK/stage"
if compgen -G "$HERE/hp-pkg/hardpoint-os_*.deb" >/dev/null; then
    cp "$HERE"/hp-pkg/hardpoint-os_*.deb "$WORK/stage/"
else
    log "Building the hardpoint-os package"
    bash "$HERE/tools/build-deb.sh" "$WORK/stage" >/dev/null
fi
log "Package: $(cd "$WORK/stage" && ls hardpoint-os_*.deb)"

# ---------------------------------------------------------------- 4. customise (chroot)
R="$WORK/root"
mount --bind /dev "$R/dev"; mount --bind /dev/pts "$R/dev/pts"
mount -t proc proc "$R/proc"; mount -t sysfs sys "$R/sys"; mount -t tmpfs tmpfs "$R/run"
mkdir -p "$R/tmp/hp" "$WORK/stage"
mount --bind "$WORK/stage" "$R/tmp/hp"

rsync -a "$HERE/config/" "$WORK/stage/config/"
cp "$HERE/tools/customize.sh" "$WORK/stage/"
mkdir -p "$WORK/stage/pkgs"
if compgen -G "$HERE/extra-pkgs/*.deb" >/dev/null; then cp "$HERE"/extra-pkgs/*.deb "$WORK/stage/pkgs/"; fi
cat > "$WORK/stage/build.env" <<EOF
HP_NAME="$HP_NAME"
HP_EDITION="$HP_EDITION"
HP_BASE_VERSION="$HP_BASE_VERSION"
HP_VERSION="$VERSION"
HP_HOME_URL="$HP_HOME_URL"
INSTALLER="$INSTALLER"
EOF

cp -L /etc/resolv.conf "$R/etc/resolv.conf.hp" 2>/dev/null || true
mv "$R/etc/resolv.conf" "$R/etc/resolv.conf.base" 2>/dev/null || true
cp -L /etc/resolv.conf "$R/etc/resolv.conf"
printf '#!/bin/sh\nexit 101\n' > "$R/usr/sbin/policy-rc.d"; chmod +x "$R/usr/sbin/policy-rc.d"

log "Customising the system (packages, apps, security, branding)"
chroot "$R" /usr/bin/env -i HOME=/root PATH=/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 \
    bash /tmp/hp/customize.sh

rm -f "$R/usr/sbin/policy-rc.d" "$R/etc/resolv.conf"
if [[ -e $R/etc/resolv.conf.base || -L $R/etc/resolv.conf.base ]]; then mv "$R/etc/resolv.conf.base" "$R/etc/resolv.conf"; fi
rm -f "$R/etc/resolv.conf.hp"
cleanup
rm -rf "$R/tmp/hp" "$R/tmp/"* "$R/var/tmp/"* "$R/root/.cache"

# ---------------------------------------------------------------- 5. live boot files
log "Updating live boot files"
C="$WORK/iso/casper"
KVER="$(ls "$R/lib/modules" | sort -V | tail -1)"
kern="$R/boot/vmlinuz-$KVER"
initrd="$R/boot/initrd.img-$KVER"
[[ -f $initrd ]] || die "No initrd for kernel $KVER in the customised system."
if [[ ! -f $kern ]]; then
    # Ubuntu images leave the kernel out of the system image (the installer copies the live one);
    # keep the ISO's kernel, which must match the modules in the image
    kern=""
    live="$(file -b "$C/vmlinuz" 2>/dev/null | grep -oE 'version [^ ]+' | cut -d' ' -f2)"
    [[ -z $live || $live == "$KVER" ]] || die "Live kernel $live does not match the image's modules ($KVER)."
    log "Kernel $KVER: keeping the ISO's kernel"
fi
# Replace every kernel and initrd the boot menus point at (names differ between base images,
# e.g. casper/vmlinuz + casper/initrd, or hwe-* variants). The initrd carries the boot splash,
# so a missed one shows the upstream logo when booting from a USB stick.
mapfile -t BOOTREFS < <(grep -rhoE '/casper/[A-Za-z0-9._-]+' "$WORK/iso/boot" "$WORK/iso/isolinux" 2>/dev/null | sort -u)
for f in "$C"/vmlinuz* "$C"/initrd* "$C"/hwe-vmlinuz* "$C"/hwe-initrd*; do
    [[ -f $f ]] && BOOTREFS+=("/casper/$(basename "$f")")
done
mapfile -t BOOTREFS < <(printf '%s\n' "${BOOTREFS[@]}" | sort -u)
replaced=0
for ref in "${BOOTREFS[@]}"; do
    f="$WORK/iso$ref"
    [[ -f $f ]] || continue
    case "$(basename "$f")" in
        *vmlinuz*) if [[ -n $kern ]]; then cp "$kern" "$f"; log "Kernel  -> $ref"; fi; replaced=$((replaced + 1)) ;;
        *initrd*)  cp "$initrd" "$f"; replaced=$((replaced + 1)); log "Initrd  -> $ref (HardPoint boot splash)" ;;
    esac
done
((replaced >= 2)) || die "Could not find the live kernel/initrd to replace (boot menu refs: ${BOOTREFS[*]:-none})."

chroot "$R" dpkg-query -W --showformat='${Package} ${Version}\n' > "$C/filesystem.manifest" 2>/dev/null || true
du -sx --block-size=1 "$R" | cut -f1 > "$C/filesystem.size"
# Keep the base image's list of live-only packages (removed from the installed system by the installer)

# Boot menu + disk info
find "$WORK/iso/boot" "$WORK/iso/isolinux" -maxdepth 3 -name '*.cfg' 2>/dev/null | while read -r cfg; do
    sed -i -e "s/Kubuntu [0-9.]*\( LTS\)\?/$HP_NAME/g" -e "s/Kubuntu/$HP_NAME/g" "$cfg"
done
echo "$HP_NAME $VERSION amd64 - Release" > "$WORK/iso/.disk/info"
if [[ -d $WORK/iso/boot/grub ]]; then
    cp "$R/usr/share/hardpoint/branding/grub.png" "$WORK/iso/boot/grub/hardpoint.png"
    grep -q hardpoint.png "$WORK/iso/boot/grub/grub.cfg" || sed -i '1i set color_normal=light-gray/black\nset menu_color_highlight=white/magenta\nif loadfont unicode ; then insmod png ; background_image /boot/grub/hardpoint.png ; fi' "$WORK/iso/boot/grub/grub.cfg"
fi

# ---------------------------------------------------------------- 6. pack
log "Compressing the system image (xz — slowest step)"
mksquashfs "$R" "$C/filesystem.squashfs" -noappend -comp xz -b 1M -Xdict-size 100% -no-progress -quiet
log "System image: $(du -h "$C/filesystem.squashfs" | cut -f1)"

(cd "$WORK/iso" && find . -type f ! -name md5sum.txt ! -path './boot.catalog' ! -path './boot/grub/i386-pc/eltorito.img' \
    ! -path './isolinux/*' -print0 | xargs -0 md5sum > md5sum.txt)

rm -f "$WORK/iso/boot.catalog"
log "Building the ISO with the same boot setup as the base image"
mapfile -t BOOTOPTS < <(xorriso -indev "$BASE" -report_el_torito as_mkisofs 2>/dev/null | grep -v '^-V ' | xargs -n1 printf '%s\n' 2>/dev/null)
((${#BOOTOPTS[@]} > 0)) || die "Could not read the boot layout of the base ISO."
xorriso -as mkisofs -o "$OUT/$ISO_NAME" -V "HardPoint OS ${HP_BASE_VERSION}" "${BOOTOPTS[@]}" "$WORK/iso"

(cd "$OUT" && sha256sum "$ISO_NAME" > SHA256SUMS)
cp "$WORK/stage/build-report.txt" "$OUT/build-report.txt" 2>/dev/null || true
# How the ISO boots from a USB stick (Rufus DD mode / dd / Etcher): hybrid MBR + GPT + EFI partition
{
    echo "== ISO boot layout (for USB sticks)"
    xorriso -indev "$OUT/$ISO_NAME" -report_system_area plain 2>/dev/null
    echo "== Partition table"
    fdisk -l "$OUT/$ISO_NAME" 2>/dev/null
    echo "== Boot options used"; printf '%s\n' "${BOOTOPTS[@]}"
    echo "== Live kernel/initrd replaced"; printf '%s\n' "${BOOTREFS[@]}"
    echo "== Boot splash inside each live initrd"
    for f in "$WORK"/iso/casper/*initrd*; do
        [[ -f $f ]] || continue
        printf '%s: ' "$(basename "$f")"
        if command -v lsinitramfs >/dev/null; then
            lsinitramfs "$f" 2>/dev/null | grep -oE 'plymouth/themes/[^/]+/[^/]+\.plymouth$|etc/plymouth/plymouthd.conf' | sort -u | tr '\n' ' '
        fi
        echo
    done
} >> "$OUT/build-report.txt"
umount "$WORK/mnt" 2>/dev/null || true
log "Done: $OUT/$ISO_NAME ($(du -h "$OUT/$ISO_NAME" | cut -f1))"
