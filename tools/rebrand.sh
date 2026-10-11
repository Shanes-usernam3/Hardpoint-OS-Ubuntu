#!/usr/bin/env bash
# Runs INSIDE the chroot. Replaces Zorin OS names and logos with HardPoint OS,
# as Zorin's trademark policy requires for a derivative.
#
# Every file we replace is "diverted" with dpkg-divert first, so later Zorin
# package updates write their version next to ours (*.zorin) instead of
# overwriting the HardPoint branding.
#
# Logo images are only listed here (/tmp/hp/logo-targets.txt); build.sh renders
# a HardPoint logo at the exact size of each one after the chroot step.
set -euo pipefail
S=/tmp/hp
# shellcheck source=/dev/null
source "$S/build.env"
log() { printf '\e[1;36m  ->\e[0m %s\n' "$*"; }

divert() {  # divert <path>: keep the packaged original as <path>.zorin
    local f="$1"
    if ! dpkg-divert --list "$f" | grep -q .; then
        dpkg-divert --quiet --local --rename --divert "$f.zorin" --add "$f"
    fi
}

# ------------------------------------------------------------ OS identity
log "Rebranding OS identity"
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-noble}}")"
UBUNTU_VER="$(. /etc/os-release && echo "${VERSION_ID:-}")"
OSREL=/usr/lib/os-release
[[ -L /etc/os-release ]] || OSREL=/etc/os-release
divert "$OSREL"
cat > "$OSREL" <<EOF
PRETTY_NAME="$HP_NAME $UBUNTU_VER ($HP_EDITION)"
NAME="$HP_NAME"
VERSION_ID="$UBUNTU_VER"
VERSION="$UBUNTU_VER ($HP_EDITION)"
VERSION_CODENAME=$CODENAME
ID=hardpoint
ID_LIKE="ubuntu debian"
HOME_URL="$HP_HOME_URL"
SUPPORT_URL="$HP_HOME_URL"
BUG_REPORT_URL="$HP_HOME_URL/issues"
LOGO=hardpoint
UBUNTU_CODENAME=$CODENAME
IMAGE_VERSION="$HP_VERSION"
EOF
[[ -e /etc/os-release ]] || ln -s ../usr/lib/os-release /etc/os-release

if [[ -f /etc/lsb-release ]]; then divert /etc/lsb-release; fi
cat > /etc/lsb-release <<EOF
DISTRIB_ID=HardPoint
DISTRIB_RELEASE=$UBUNTU_VER
DISTRIB_CODENAME=$CODENAME
DISTRIB_DESCRIPTION="$HP_NAME $UBUNTU_VER"
EOF
# Software & Updates / add-apt-repository look up a template named after DISTRIB_ID
for t in /usr/share/python-apt/templates/Zorin.info /usr/share/python-apt/templates/Zorin.mirrors; do
    [[ -f $t ]] && cp "$t" "${t/Zorin/HardPoint}"
done
if [[ ! -f /usr/share/python-apt/templates/HardPoint.info && -f /usr/share/python-apt/templates/Ubuntu.info ]]; then
    cp /usr/share/python-apt/templates/Ubuntu.info /usr/share/python-apt/templates/HardPoint.info
    [[ -f /usr/share/python-apt/templates/Ubuntu.mirrors ]] && cp /usr/share/python-apt/templates/Ubuntu.mirrors /usr/share/python-apt/templates/HardPoint.mirrors
fi
for f in /etc/issue /etc/issue.net; do
    [[ -f $f ]] && divert "$f"
done
printf '%s %s \\n \\l\n\n' "$HP_NAME" "$UBUNTU_VER" > /etc/issue
printf '%s %s\n' "$HP_NAME" "$UBUNTU_VER" > /etc/issue.net

# Live session user/host name
if [[ -f /etc/casper.conf ]]; then
    sed -i -E 's/^(export )?USERNAME=.*/export USERNAME="hardpoint"/; s/^(export )?USERFULLNAME=.*/export USERFULLNAME="HardPoint Live"/; s/^(export )?HOST=.*/export HOST="hardpoint"/; s/^(export )?BUILD_SYSTEM=.*/export BUILD_SYSTEM="Ubuntu"/' /etc/casper.conf
fi

# ------------------------------------------------------------ app names
log "Renaming Zorin-branded launchers"
n=0
while IFS= read -r -d '' f; do
    grep -qE '^(Name|GenericName|Comment|X-GNOME-FullName|Keywords)(\[[^]]*\])?=.*Zorin' "$f" || continue
    divert "$f"
    sed -E '/^(Name|GenericName|Comment|X-GNOME-FullName)(\[[^]]*\])?=/ { s/Zorin OS [0-9.]+( Core| Pro| Lite)?/HardPoint OS/g; s/Zorin OS/HardPoint OS/g; s/Zorin/HardPoint/g }' \
        "$f.zorin" > "$f"
    n=$((n + 1))
done < <(find /usr/share/applications /etc/xdg/autostart /usr/share/ubiquity -name '*.desktop' -type f -print0 2>/dev/null)
log "Renamed $n launchers"

# Desktop shortcut in the live session
if [[ -f /usr/share/applications/ubiquity.desktop ]]; then
    sed -i -E 's|^Icon=.*|Icon=hardpoint|' /usr/share/applications/ubiquity.desktop
fi

# ------------------------------------------------------------ installer slideshow
if [[ -d /usr/share/ubiquity-slideshow ]]; then
    log "Replacing the installer slideshow"
    [[ -d /usr/share/ubiquity-slideshow/slides.zorin ]] || mv /usr/share/ubiquity-slideshow/slides /usr/share/ubiquity-slideshow/slides.zorin
    rm -rf /usr/share/ubiquity-slideshow/slides
    cp -a /usr/lib/hardpoint/slideshow /usr/share/ubiquity-slideshow/slides
    cp /usr/share/hardpoint/branding/logo-glow-256.png /usr/share/ubiquity-slideshow/slides/logo.png
fi

# ------------------------------------------------------------ logos
log "Finding Zorin logos to replace"
: > "$S/logo-targets.txt"
while IFS= read -r -d '' f; do
    case "$f" in */hardpoint/*|*/slides.zorin/*|*.zorin) continue ;; esac
    divert "$f"
    cp "$f.zorin" "$f"          # placeholder until build.sh renders ours
    echo "$f" >> "$S/logo-targets.txt"
done < <(find /usr/share/pixmaps /usr/share/icons /usr/share/zorin* /usr/share/gnome-shell /usr/share/ubiquity \
    /usr/share/plymouth /usr/share/backgrounds/zorin* /usr/share/gdm 2>/dev/null \
    -type f \( -iname '*zorin*logo*' -o -iname '*logo*zorin*' -o -iname 'distributor-logo*' -o -iname 'start-here*' \
    -o -iname 'zorin-menu*' -o -ipath '/usr/share/plymouth/themes/*/watermark*' -o -ipath '/usr/share/plymouth/themes/zorin*/*logo*' -o -iname 'zorin-os*' -o -iname 'zorin.*' -o -iname 'zorin-symbolic*' -o -iname 'ubuntu-logo*' \) \
    \( -iname '*.png' -o -iname '*.svg' \) -print0)
log "$(wc -l < "$S/logo-targets.txt") logo images will be replaced"

# Hide Zorin's own boot splash so ours is the only choice
for t in /usr/share/plymouth/themes/zorin*; do
    [[ -d $t ]] && log "Keeping $(basename "$t") installed but not default"
done
