#!/usr/bin/env bash
# Runs INSIDE the unpacked Zorin live system (chroot) during the build.
# Adds software, HardPoint apps, security defaults and branding.
set -euo pipefail
S=/tmp/hp
# shellcheck source=/dev/null
source "$S/build.env"
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -y -q -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

log() { printf '\e[1;36m  ->\e[0m %s\n' "$*"; }
warn() { printf '\e[1;33m  WARN:\e[0m %s\n' "$*" >&2; }

# ------------------------------------------------------------ apt sources
log "Enabling Ubuntu universe/multiverse and 32-bit packages (Steam)"
dpkg --add-architecture i386
python3 - <<'PY'
import glob, re
COMP = ["main", "restricted", "universe", "multiverse"]
for f in ["/etc/apt/sources.list"] + glob.glob("/etc/apt/sources.list.d/*.list"):
    try: lines = open(f).read().splitlines()
    except FileNotFoundError: continue
    out = []
    for l in lines:
        m = re.match(r"^(deb(?:-src)?\s+(?:\[[^]]*\]\s+)?\S*ubuntu\.com\S*\s+\S+)\s+(.*)$", l)
        if m:
            comps = m.group(2).split()
            l = m.group(1) + " " + " ".join(comps + [c for c in COMP if c not in comps])
        out.append(l)
    open(f, "w").write("\n".join(out) + "\n")
for f in glob.glob("/etc/apt/sources.list.d/*.sources"):
    blocks = open(f).read().split("\n\n")
    for i, b in enumerate(blocks):
        if "ubuntu.com" in b:
            def fix(m):
                comps = m.group(1).split()
                return "Components: " + " ".join(comps + [c for c in COMP if c not in comps])
            blocks[i] = re.sub(r"^Components:[ \t]*(.*)$", fix, b, flags=re.M)
    open(f, "w").write("\n\n".join(blocks))
PY

log "Adding Microsoft repositories (Edge, VS Code, Intune)"
"${APT[@]}" install curl gpg ca-certificates >/dev/null
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --yes -o /usr/share/keyrings/microsoft.gpg
cat > /etc/apt/sources.list.d/microsoft.sources <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/edge
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg

Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg

Types: deb
URIs: https://packages.microsoft.com/ubuntu/24.04/prod
Suites: noble
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
# The Edge and VS Code packages try to add their own copies of these repos
echo "code code/add-microsoft-repo boolean false" | debconf-set-selections
mkdir -p /etc/default && touch /etc/default/google-chrome /etc/default/microsoft-edge
# Steam licence prompts
echo "steam steam/question select I AGREE" | debconf-set-selections
echo "steam steam/license note ''" | debconf-set-selections
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections

apt-get update -q

# ------------------------------------------------------------ packages
log "Installing HardPoint packages"
mapfile -t WANT < <(grep -vE '^\s*(#|$)' "$S/config/packages.install" | awk '{print $1}')
OK=() SKIP=()
for p in "${WANT[@]}"; do
    if [[ -n $(apt-cache policy "$p" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -v '(none)') ]]; then OK+=("$p"); else SKIP+=("$p"); fi
done
((${#SKIP[@]})) && warn "Not available, skipped: ${SKIP[*]}"
# One batch is fastest; if a single package's install script fails inside the
# image build, fall back to one-by-one so the rest still get installed.
if ! "${APT[@]}" install --no-install-recommends "${OK[@]}"; then
    warn "Batch install failed — installing one by one"
    dpkg --configure -a || true
    for p in "${OK[@]}"; do
        if ! "${APT[@]}" install --no-install-recommends "$p" >/tmp/apt-one.log 2>&1; then
            warn "Failed: $p"; tail -5 /tmp/apt-one.log >&2; SKIP+=("$p")
            dpkg --configure -a >/dev/null 2>&1 || true
            apt-get -f install -y -q >/dev/null 2>&1 || true
        fi
    done
fi
# Recommends for the GUI apps that need them to look right
"${APT[@]}" install wireshark remmina gufw virt-manager >/dev/null || true
printf '%s\n' "${SKIP[@]}" > /usr/share/hardpoint-skipped-packages.txt 2>/dev/null || true

# Extra groups (docker, wireshark, libvirt...) are added to admins on first boot (hardpoint-firstboot)

# ------------------------------------------------------------ Entra sign-in (Himmelblau)
if compgen -G "$S/pkgs/*.deb" >/dev/null; then
    log "Bundling Microsoft Entra ID sign-in (Himmelblau)"
    mkdir -p /usr/share/hardpoint/pkgs
    for d in "$S"/pkgs/*.deb; do
        case "$(dpkg-deb -f "$d" Package)" in
            himmelblau|pam-himmelblau|nss-himmelblau|himmelblau-sso|himmelblau-qr-greeter) cp "$d" /usr/share/hardpoint/pkgs/ ;;
        esac
    done
    # Pre-install dependencies so turning it on later works offline
    deps="$(for d in /usr/share/hardpoint/pkgs/*.deb; do dpkg-deb -f "$d" Depends; done | tr ',' '\n' \
        | sed -E 's/\(.*\)//; s/\|.*//; s/:any//; s/ //g' | grep -vE '^(himmelblau|pam-himmelblau|nss-himmelblau|himmelblau-.*)?$' | sort -u)"
    # shellcheck disable=SC2086
    [[ -n $deps ]] && { "${APT[@]}" install --no-install-recommends $deps || warn "Some Himmelblau dependencies could not be preinstalled"; }
    log "Checking Himmelblau installs cleanly next to the Intune app"
    if apt-get install -s /usr/share/hardpoint/pkgs/*.deb > /tmp/hb-sim.txt 2>&1; then
        log "Himmelblau: OK ($(grep -c '^Inst' /tmp/hb-sim.txt) packages would be installed)"
    else
        warn "Himmelblau install simulation failed:"; tail -20 /tmp/hb-sim.txt >&2
    fi
else
    warn "No Himmelblau packages supplied (extra-pkgs/) — work/school sign-in will be unavailable"
fi

# ------------------------------------------------------------ HardPoint files
log "Installing HardPoint apps and settings"
cp -R --preserve=mode,timestamps "$S/overlay/." /
chmod 755 /usr/bin/hardpoint-* /usr/lib/hardpoint/hp-* 2>/dev/null || true
mkdir -p /usr/share/hardpoint/branding /usr/share/backgrounds/hardpoint
cp "$S"/branding/*.png "$S"/branding/*.svg /usr/share/hardpoint/branding/
cp "$S/branding/wallpaper-dark.png" /usr/share/backgrounds/hardpoint/byte-dark.png
cp "$S/branding/wallpaper-light.png" /usr/share/backgrounds/hardpoint/byte-light.png
cp "$S/branding/login.png" /usr/share/backgrounds/hardpoint/login.png
cp "$S/config/flatpaks.list" /usr/share/hardpoint/flatpaks.list
install -Dm644 "$S/branding/hardpoint-logo.svg" /usr/share/icons/hicolor/scalable/apps/hardpoint.svg
for s in 16 22 24 32 48 64 96 128 256 512; do
    install -Dm644 "$S/branding/logo-$s.png" "/usr/share/icons/hicolor/${s}x${s}/apps/hardpoint.png"
done
mkdir -p /usr/share/gnome-background-properties
cat > /usr/share/gnome-background-properties/hardpoint.xml <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>HardPoint Byte</name>
    <filename>/usr/share/backgrounds/hardpoint/byte-light.png</filename>
    <filename-dark>/usr/share/backgrounds/hardpoint/byte-dark.png</filename-dark>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#0A0E17</pcolor>
    <scolor>#1A1B39</scolor>
  </wallpaper>
</wallpapers>
EOF

# Flathub for the apps HardPoint Setup offers
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || warn "Flathub remote not added"

# ------------------------------------------------------------ desktop defaults
log "Setting desktop defaults (Byte look)"
pick_theme() { for t in "$@"; do [[ -d /usr/share/themes/$t ]] && { echo "$t"; return; }; done; }
pick_icons() { for t in "$@"; do [[ -d /usr/share/icons/$t ]] && { echo "$t"; return; }; done; }
GTK="$(pick_theme ZorinPurple-Dark ZorinBlue-Dark Yaru-purple-dark Adwaita-dark || true)"
ICONS="$(pick_icons ZorinPurple-Dark ZorinBlue-Dark Yaru-purple-dark Adwaita || true)"
log "Theme: ${GTK:-default}, icons: ${ICONS:-default}"
mkdir -p /etc/dconf/db/local.d /etc/dconf/db/gdm.d /etc/dconf/profile
{
    echo "# HardPoint OS defaults (users can change all of these)"
    echo "[org/gnome/desktop/background]"
    echo "picture-uri='file:///usr/share/backgrounds/hardpoint/byte-light.png'"
    echo "picture-uri-dark='file:///usr/share/backgrounds/hardpoint/byte-dark.png'"
    echo "picture-options='zoom'"
    echo "primary-color='#0A0E17'"
    echo
    echo "[org/gnome/desktop/screensaver]"
    echo "picture-uri='file:///usr/share/backgrounds/hardpoint/login.png'"
    echo "lock-enabled=true"
    echo "lock-delay=uint32 0"
    echo
    echo "[org/gnome/desktop/interface]"
    echo "color-scheme='prefer-dark'"
    [[ -n $GTK ]] && echo "gtk-theme='$GTK'"
    [[ -n $ICONS ]] && echo "icon-theme='$ICONS'"
    echo "enable-animations=true"
    echo
    echo "[org/gnome/desktop/privacy]"
    echo "remove-old-temp-files=true"
    echo "remove-old-trash-files=true"
    echo "report-technical-problems=false"
    echo "send-software-usage-stats=false"
    echo
    echo "[org/gnome/desktop/session]"
    echo "idle-delay=uint32 600"
    echo
    echo "[org/gnome/mutter]"
    echo "center-new-windows=true"
} > /etc/dconf/db/local.d/00-hardpoint
{
    echo "[org/gnome/login-screen]"
    echo "logo='/usr/share/hardpoint/branding/login-logo.png'"
    echo "disable-restart-buttons=false"
    echo
    echo "[org/gnome/desktop/interface]"
    echo "color-scheme='prefer-dark'"
} > /etc/dconf/db/gdm.d/01-hardpoint
if [[ -f /etc/dconf/profile/user ]]; then
    grep -q '^system-db:local' /etc/dconf/profile/user || echo "system-db:local" >> /etc/dconf/profile/user
else
    printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
fi
if [[ -f /etc/dconf/profile/gdm ]]; then
    grep -q '^system-db:gdm' /etc/dconf/profile/gdm || sed -i '/^user-db:user/a system-db:gdm' /etc/dconf/profile/gdm
else
    printf 'user-db:user\nsystem-db:gdm\nfile-db:/usr/share/gdm/greeter-dconf-defaults\n' > /etc/dconf/profile/gdm
fi
dconf update

# Zorin's own GSettings overrides win over dconf for some keys — add ours last
mkdir -p /usr/share/glib-2.0/schemas
cat > /usr/share/glib-2.0/schemas/99_hardpoint.gschema.override <<EOF
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/hardpoint/byte-light.png'
picture-uri-dark='file:///usr/share/backgrounds/hardpoint/byte-dark.png'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/hardpoint/login.png'

[org.gnome.desktop.interface]
color-scheme='prefer-dark'
${GTK:+gtk-theme='$GTK'}
${ICONS:+icon-theme='$ICONS'}
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

# ------------------------------------------------------------ security
log "Applying security defaults"
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf 2>/dev/null || true
sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/; s/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="DROP"/' /etc/default/ufw 2>/dev/null || true
for u in ufw.service apparmor.service fwupd-refresh.timer hardpoint-firstboot.service hardpoint-touchpad.service thermald.service; do
    systemctl enable "$u" >/dev/null 2>&1 || warn "Could not enable $u"
done
systemctl disable usbguard.service 2>/dev/null || true   # only on in Lockdown Mode
[[ -f /etc/usbguard/usbguard-daemon.conf ]] && sed -i 's/^IPCAllowedGroups=.*/IPCAllowedGroups=sudo/' /etc/usbguard/usbguard-daemon.conf
# No crash dumps, no core files
mkdir -p /etc/security/limits.d && echo "* hard core 0" > /etc/security/limits.d/90-hardpoint.conf
sed -i 's/^enabled=1/enabled=0/' /etc/default/apport 2>/dev/null || true
# Compressed RAM swap
printf '[zram0]\nzram-size = min(ram / 2, 8192)\ncompression-algorithm = zstd\n' > /etc/systemd/zram-generator.conf
# Installed system: hide the GRUB menu unless Shift/Esc is held, HardPoint background
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/90-hardpoint.cfg <<'EOF'
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=2
GRUB_BACKGROUND="/usr/share/hardpoint/branding/grub.png"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
EOF

# ------------------------------------------------------------ updates
log "Configuring HardPoint Update Center"
# apt downloads in the background but never installs on its own — you pick in the checklist
cat > /etc/apt/apt.conf.d/52hardpoint-periodic <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::AutocleanInterval "7";
EOF
systemctl --global enable hardpoint-update-check.timer 2>/dev/null || \
    { mkdir -p /etc/systemd/user/timers.target.wants && ln -sf /usr/lib/systemd/user/hardpoint-update-check.timer /etc/systemd/user/timers.target.wants/; }

# ------------------------------------------------------------ branding
bash "$S/rebrand.sh"
bash "$S/gdm-theme.sh" || warn "Login screen theme could not be applied"

# Boot splash
if [[ -d /usr/share/plymouth/themes/hardpoint ]]; then
    cp "$S/branding/plymouth-logo.png" "$S/branding/plymouth-dot.png" "$S/branding/plymouth-bar.png" \
       "$S/branding/plymouth-track.png" /usr/share/plymouth/themes/hardpoint/
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
        /usr/share/plymouth/themes/hardpoint/hardpoint.plymouth 300
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/hardpoint/hardpoint.plymouth
fi
# Touchpad driver order applies inside the boot image too
grep -qx 'pinctrl_alderlake' /etc/initramfs-tools/modules 2>/dev/null || printf 'pinctrl_alderlake\npinctrl_tigerlake\n' >> /etc/initramfs-tools/modules
log "Rebuilding the boot image"
update-initramfs -u -k all >/dev/null 2>&1 || warn "update-initramfs reported a problem"

# ------------------------------------------------------------ clean up
apt-get autoremove -y -q >/dev/null || true
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/hb-sim.txt
mkdir -p /var/lib/apt/lists/partial
log "Customisation complete"
