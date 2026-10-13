#!/usr/bin/env bash
# Build the hardpoint-os package: every HardPoint file plus the setup that
# applies branding and settings when it is installed or updated.
#   tools/build-deb.sh <output-dir>          (needs Pillow + numpy for the artwork)
#   HP_PKG_VERSION=18.20261012.7 tools/build-deb.sh out
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=config/base.env
source "$HERE/config/base.env"
OUT="$(realpath -m "${1:-out}")"
VERSION="${HP_PKG_VERSION:-$HP_BASE_VERSION.$(date +%Y%m%d).0}"
P="$(mktemp -d)/hardpoint-os"
mkdir -p "$P/DEBIAN" "$OUT"

# Files
cp -R --preserve=mode "$HERE/overlay/." "$P/"
B="$P/usr/share/hardpoint/branding"
mkdir -p "$B" "$P/usr/share/backgrounds/hardpoint"
python3 "$HERE/tools/make-branding.py" "$B" >/dev/null
cp "$HERE/branding/hardpoint-logo.svg" "$HERE"/branding/hardpoint-connect*.svg "$B/"
cp "$HERE"/branding/hardpoint-appearance*.svg "$B/"
if command -v rsvg-convert >/dev/null; then
    rsvg-convert -w 512 -h 512 "$HERE/branding/hardpoint-connect.svg" -o "$B/connect-512.png"
    rsvg-convert -w 512 -h 512 "$HERE/branding/hardpoint-appearance.svg" -o "$B/appearance-512.png"
fi
# Wallpapers as high-quality JPEG (a 4K PNG is ~10 MB per update)
python3 - "$B" "$P/usr/share/backgrounds/hardpoint" <<'PY'
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
for name in ("dark", "light"):
    Image.open(f"{src}/wallpaper-{name}.png").convert("RGB").save(f"{dst}/byte-{name}.jpg", quality=92, optimize=True, subsampling=0)
PY
rm -f "$B"/wallpaper-*.png
cp "$B/login.png"           "$P/usr/share/backgrounds/hardpoint/login.png"
cp "$B"/plymouth-*.png "$P/usr/share/plymouth/themes/hardpoint/"
install -Dm644 "$HERE/branding/hardpoint-logo.svg" "$P/usr/share/icons/hicolor/scalable/apps/hardpoint.svg"
for s in 16 22 24 32 48 64 96 128 256 512; do
    install -Dm644 "$B/logo-$s.png" "$P/usr/share/icons/hicolor/${s}x${s}/apps/hardpoint.png"
done
install -Dm644 "$HERE/config/flatpaks.list" "$P/usr/share/hardpoint/flatpaks.list"
mkdir -p "$P/usr/share/gnome-background-properties"
cat > "$P/usr/share/gnome-background-properties/hardpoint.xml" <<'XML'
<?xml version="1.0"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>HardPoint Byte</name>
    <filename>/usr/share/backgrounds/hardpoint/byte-light.jpg</filename>
    <filename-dark>/usr/share/backgrounds/hardpoint/byte-dark.jpg</filename-dark>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#0A0E17</pcolor>
    <scolor>#1A1B39</scolor>
  </wallpaper>
</wallpapers>
XML
cat > "$P/usr/lib/hardpoint/setup/build.env" <<ENV
HP_NAME="$HP_NAME"
HP_EDITION="$HP_EDITION"
HP_VERSION="$VERSION"
HP_HOME_URL="$HP_HOME_URL"
ENV
find "$P" -name '__pycache__' -prune -exec rm -rf {} +

# Software that comes with HardPoint OS: new entries reach installed PCs on update.
RECS="$(grep -vE '^\s*(#|$)' "$HERE/config/packages.install" | awk '{print $1}' | grep -v ':' | paste -sd, | sed 's/,/, /g')"

cat > "$P/DEBIAN/control" <<CTRL
Package: hardpoint-os
Version: $VERSION
Architecture: all
Maintainer: HardPoint Networks <noreply@hardpoint.invalid>
Section: misc
Priority: optional
Depends: python3, python3-gi, gir1.2-webkit2-4.1, python3-pil, libglib2.0-bin, libglib2.0-dev-bin, dconf-cli, plymouth, initramfs-tools, libnotify-bin, timeshift, pkexec | policykit-1
Recommends: $RECS
Description: HardPoint OS — apps, branding, security and laptop settings
 HardPoint Setup, Updates, Accounts and Security apps, the Byte-style boot
 splash, login screen and wallpapers, kernel hardening, Lockdown Mode, the
 I2C touchpad fix and the HardPoint update source. Updating this package
 updates HardPoint OS without reinstalling.
CTRL

# Files under /etc are conffiles (local edits are kept on update)
(cd "$P" && find etc -type f | sed 's|^|/|' | sort) > "$P/DEBIAN/conffiles"

cat > "$P/DEBIAN/postinst" <<'SH'
#!/bin/sh
set -e
case "$1" in
    configure)
        /usr/lib/hardpoint/setup/apply.sh || echo "hardpoint-os: some settings could not be applied (see above)" >&2
        ;;
    triggered)
        for v in Dark Light; do
            [ -d /usr/share/themes/ZorinBlue-$v ] && python3 /usr/lib/hardpoint/setup/make-theme.py \
                /usr/share/themes/ZorinBlue-$v /usr/share/themes/HardPoint-$v "$(echo $v | tr A-Z a-z)" || true
        done
        ;;
esac
exit 0
SH
chmod 755 "$P/DEBIAN/postinst"
# Rebuild the HardPoint themes when Zorin updates its themes
printf 'interest-noawait /usr/share/themes/ZorinBlue-Dark\ninterest-noawait /usr/share/themes/ZorinBlue-Light\n' > "$P/DEBIAN/triggers"

# Permissions: root-owned, scripts executable
find "$P" -path "$P/DEBIAN" -prune -o -type d -exec chmod 755 {} +
find "$P" -path "$P/DEBIAN" -prune -o -type f ! -perm -u+x -exec chmod 644 {} +
chmod 440 "$P/etc/sudoers.d/90-hardpoint"
DEB="$OUT/hardpoint-os_${VERSION}_all.deb"
dpkg-deb --root-owner-group -Zxz --build "$P" "$DEB" >/dev/null
echo "$DEB"
