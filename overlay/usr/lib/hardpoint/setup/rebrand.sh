#!/usr/bin/env bash
# Run by the hardpoint-os package (and the image build). Replaces the base system's names and
# logos with HardPoint OS (the upstream trademark policy requires this for a derivative).
#
# Every file we replace is "diverted" with dpkg-divert first, so later upstream
# package updates write their version next to ours (*.zorin) instead of
# overwriting the HardPoint branding.
#
# Logo images are listed in $S/logo-targets.txt; apply-logos.py then renders a
# HardPoint logo at the exact size of each one.
set -euo pipefail
# Work/report folder: the image build passes HP_STAGE; on an installed PC it's /var/lib/hardpoint
S="${HP_STAGE:-/var/lib/hardpoint}"
mkdir -p "$S"
# shellcheck source=/dev/null
source /usr/lib/hardpoint/setup/build.env
INSTALLER=none
[[ -d /usr/lib/ubiquity ]] && INSTALLER=ubiquity
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
PRETTY_NAME="$HP_NAME $UBUNTU_VER${HP_EDITION:+ ($HP_EDITION)}"
NAME="$HP_NAME"
VERSION_ID="$UBUNTU_VER"
VERSION="$UBUNTU_VER${HP_EDITION:+ ($HP_EDITION)}"
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
log "Renaming upstream-branded launchers"
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

# ------------------------------------------------------------ names inside the base system's apps
# Window titles, labels, extension names and descriptions live in the apps' own
# files. Replace the visible names only:
#  - comment lines (license and credit headers) are never changed
#  - in .py/.js code only lines with visible text (_(), label, title, name) change
#  - code identifiers (zorin_appearance, com.zorin.*, "Zorin"+colour theme ids) stay
log "Renaming upstream product names inside the base system's apps"
PRODUCTS='Appearance|Connect|Menu|Taskbar|Welcome|AppIndicators|Desktop Cube|Desktop Icons|Magic Lamp Effect|Printers|Screen Keyboard Panel Button|Spatial Window Switcher|Tiling Shell|Window Move Effect|Auto Theme|Tour|Upgrader'
SUBST="s/Zorin OS/HardPoint OS/g
s/Zorin ($PRODUCTS)/HardPoint \1/g
s/Zorin logomark/HardPoint logo/g
s/'Zorin ' \+/'HardPoint ' +/g
s/_\('Zorin'\)/_('HardPoint')/g
s/<vendor>Zorin<\/vendor>/<vendor>HardPoint<\/vendor>/g
s/<name>Zorin<\/name>/<name>Classic<\/name>/g
s/<name>Zorin ([^<]+)<\/name>/<name>\1<\/name>/g"
SED_TEXT="$S/rename-text.sed"; SED_CODE="$S/rename-code.sed"
{ echo '/^[[:space:]]*(#|\*|\/\/|\/\*)/!{'; printf '%s\n' "$SUBST"; echo '}'; } > "$SED_TEXT"
{ echo '/^[[:space:]]*(#|\*|\/\/|\/\*)/!{'; echo '/(_\(|label|[Tt]itle|"name"|[Nn]ame:|setHeader|set_application_name)/{'; printf '%s\n' "$SUBST"; echo '}'; echo '}'; } > "$SED_CODE"
VISIBLE="Zorin (OS|logomark|$PRODUCTS)|'Zorin '|_\('Zorin'\)|<vendor>Zorin<|<name>Zorin"

rename_file() {  # rename_file <installed path>
    local f="$1" src="$1"
    dpkg-divert --list "$f" | grep -q . && src="$f.zorin"
    [[ -f $src ]] || return 1
    grep -Iq . "$src" 2>/dev/null || return 1
    grep -qE "$VISIBLE" "$src" || return 1
    divert "$f"
    case "$f" in
        *.py|*.js) sed -E -f "$SED_CODE" "$f.zorin" > "$f" ;;
        *)         sed -E -f "$SED_TEXT" "$f.zorin" > "$f" ;;
    esac
    chmod --reference="$f.zorin" "$f"
}

rename_gresource() {  # unpack, rename text inside, repack
    local f="$1" src="$1" w r n=0
    dpkg-divert --list "$f" | grep -q . && src="$f.zorin"
    grep -q 'Zorin' "$src" 2>/dev/null || return 1
    w="$(mktemp -d)"
    while read -r r; do
        mkdir -p "$w/root$(dirname "$r")"
        gresource extract "$src" "$r" > "$w/root$r"
    done < <(gresource list "$src")
    while IFS= read -r -d '' t; do
        grep -Iq . "$t" 2>/dev/null || continue
        grep -qE "$VISIBLE" "$t" || continue
        case "$t" in *.js) sed -E -i -f "$SED_CODE" "$t" ;; *) sed -E -i -f "$SED_TEXT" "$t" ;; esac
        n=$((n + 1))
    done < <(find "$w/root" -type f -print0)
    if ((n > 0)); then
        { echo '<?xml version="1.0" encoding="UTF-8"?><gresources><gresource prefix="/">'
          (cd "$w/root" && find . -type f | sed 's|^\./||' | sort | sed 's|.*|<file>&</file>|')
          echo '</gresource></gresources>'; } > "$w/res.xml"
        divert "$f"
        if glib-compile-resources --sourcedir="$w/root" --target="$w/out.gresource" "$w/res.xml"; then
            cp "$w/out.gresource" "$f"; chmod 644 "$f"
        else
            cp "$f.zorin" "$f"; n=0
        fi
    fi
    rm -rf "$w"
    ((n > 0))
}

n=0 g=0
while IFS= read -r pkg; do
    case "$pkg" in zorin-os-upgrader|zorin-os-docs|zorin-os-census) continue ;; esac   # hidden / not shown
    while IFS= read -r f; do
        [[ -f $f && ! -L $f ]] || continue
        case "$f" in
            /etc/*|*.zorin|*.desktop|*.mo|*.png|*.jpg|*.svg|*.so|*.so.*|*.pyc|*.gz|/usr/share/doc/*|/usr/share/man/*) continue ;;
            *.gresource) rename_gresource "$f" && g=$((g + 1)); continue ;;
        esac
        rename_file "$f" && n=$((n + 1))
    done < <(dpkg -L "$pkg" 2>/dev/null)
done < <( { dpkg-query -W -f='${Package}\n' '*zorin*' 2>/dev/null; echo software-properties-gtk; } | sort -u)
log "Renamed product names in $n files and $g resource bundles" | tee -a "$S/build-report.txt"
# Schemas may contain renamed descriptions
glib-compile-schemas /usr/share/glib-2.0/schemas 2>/dev/null || true

# ------------------------------------------------------------ last visible upstream text
log "Renaming the remaining visible upstream text"
# Password prompt of the (hidden) upstream upgrader
for f in /usr/share/polkit-1/actions/com.zorin.*.policy; do
    [[ -f $f && ! $f == *.zorin ]] || continue
    divert "$f"
    sed -E 's/<vendor>Zorin<\/vendor>/<vendor>HardPoint<\/vendor>/; s/Zorin OS/HardPoint OS/g; s/Zorin/HardPoint/g' "$f.zorin" > "$f"
done
# Icon set names shown in Appearance
for f in /usr/share/icons/Zorin*/index.theme; do
    [[ -f $f ]] || continue
    grep -qE '^Name=Zorin' "$f" || { dpkg-divert --list "$f" | grep -q . || continue; }
    divert "$f"
    sed -E 's/^Name=Zorin ?/Name=Classic /; s/^Name=Classic $/Name=Classic/; s/^Comment=.*Zorin.*/Comment=Classic icon set/' "$f.zorin" > "$f"
done
# Installer: the census is removed, so its checkbox and text go too (hidden, never shown)
for UI in /usr/share/ubiquity/gtk/*.ui; do
    [[ -f $UI && ! $UI == *.zorin ]] || continue
    src="$UI"; dpkg-divert --list "$UI" | grep -q . && src="$UI.zorin"
    grep -qiE 'census|Zorin' "$src" || continue
    divert "$UI"
    python3 - "$UI.zorin" "$UI" <<'PY'
import re, sys
import xml.etree.ElementTree as ET
src, dst = sys.argv[1], sys.argv[2]
tree = ET.parse(src)
root = tree.getroot()
def set_prop(obj, name, value):
    for p in obj.findall("property"):
        if p.get("name") == name:
            p.text = value
            return
    e = ET.SubElement(obj, "property", {"name": name}); e.text = value
for obj in root.iter("object"):
    oid = obj.get("id", "")
    texts = " ".join((p.text or "") for p in obj.findall("property") if p.get("name") in ("label", "tooltip_text", "tooltip_markup"))
    if re.search("census", oid + " " + texts, re.I):
        set_prop(obj, "visible", "False")
        set_prop(obj, "no_show_all", "True")
for p in root.iter("property"):
    if p.text and "Zorin" in p.text:
        p.text = re.sub(r"Zorin OS", "HardPoint OS", p.text).replace("Zorin", "HardPoint")
tree.write(dst, encoding="utf-8", xml_declaration=True)
PY
done

# ------------------------------------------------------------ logos
log "Finding upstream logos to replace"
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
# Any other icon whose name says "zorin" is an upstream logo (menu button, about page, etc.)
while IFS= read -r -d '' f; do
    case "$f" in */hardpoint/*|*.zorin) continue ;; esac
    grep -qxF "$f" "$S/logo-targets.txt" && continue
    divert "$f"; cp "$f.zorin" "$f"; echo "$f" >> "$S/logo-targets.txt"
done < <(find /usr/share/icons /usr/share/pixmaps /usr/share/gnome-shell/extensions -type f \
    \( -iname '*zorin*' -o -ipath '*zorin*menu*/*logo*' -o -ipath '*zorin*menu*/*icon*' \) \
    \( -iname '*.png' -o -iname '*.svg' \) -print0 2>/dev/null)
# The phone link and Appearance apps keep working; they get HardPoint icons
while IFS= read -r -d '' f; do
    case "$f" in *.zorin) continue ;; esac
    grep -qxF "$f" "$S/logo-targets.txt" && continue
    divert "$f"; cp "$f.zorin" "$f"; echo "$f" >> "$S/logo-targets.txt"
done < <(find /usr/share/icons /usr/share/pixmaps /usr/share/gnome-shell/extensions -type f \
    \( -iname '*zorin-connect*' -o -iname '*ZorinConnect*' -o -iname 'zorin-appearance*' \) \( -iname '*.png' -o -iname '*.svg' \) -print0 2>/dev/null)
log "$(wc -l < "$S/logo-targets.txt") logo images will be replaced"

# Build report: upstream names still present, for checking the next build
set +e
{
    echo "== Installer: $INSTALLER"
    echo "== Logo images replaced"; cat "$S/logo-targets.txt"
    echo "== Image files still containing 'zorin' (not replaced)"
    find /usr/share -type f \( -iname '*.png' -o -iname '*.svg' \) -ipath '*zorin*' 2>/dev/null \
        | grep -vxFf "$S/logo-targets.txt" | grep -vE '\.zorin$|/backgrounds/|/themes/' | head -300
    echo "== Files still showing 'Zorin Appearance' (binary or not handled)"
    grep -rlI --exclude='*.zorin' 'Zorin Appearance' /usr/share /usr/lib/python3/dist-packages /usr/bin 2>/dev/null | head -20
    grep -rl --exclude='*.zorin' 'Zorin Appearance' /usr/share /usr/lib/python3/dist-packages 2>/dev/null | grep -v '\.mo$' | head -20
    echo "== Upstream GNOME Shell extensions"; ls -d /usr/share/gnome-shell/extensions/*zorin* 2>/dev/null
    echo "== Menu-related settings keys"
    grep -l 'zorin' /usr/share/glib-2.0/schemas/*.xml 2>/dev/null | xargs -r grep -hoE 'name="[a-z-]*(icon|logo|button)[a-z-]*"' | sort -u
} >> "$S/build-report.txt"
set -e

# Hide the upstream boot splash so ours is the only choice
for t in /usr/share/plymouth/themes/zorin*; do
    [[ -d $t ]] && log "Keeping $(basename "$t") installed but not default"
done
