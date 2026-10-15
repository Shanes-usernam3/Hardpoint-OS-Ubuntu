#!/usr/bin/env bash
# HardPoint OS — apply HardPoint settings and branding to this system.
# Run by the hardpoint-os package every time it is installed or updated (and by
# the ISO build), so every fix pushed to GitHub reaches installed PCs as a
# normal update. Safe to run again: each step checks or replaces what is there.
set -euo pipefail
D=/usr/lib/hardpoint/setup
S="${HP_STAGE:-/var/lib/hardpoint}"
mkdir -p "$S"
log() { printf '  -> %s\n' "$*"; }
warn() { printf '  WARN: %s\n' "$*" >&2; }

# ------------------------------------------------------------ desktop defaults
log "Setting desktop defaults (Byte look)"
pick_theme() { for t in "$@"; do [[ -d /usr/share/themes/$t ]] && { echo "$t"; return; }; done; }
pick_icons() { for t in "$@"; do [[ -d /usr/share/icons/$t ]] && { echo "$t"; return; }; done; }
# HardPoint Dark / Light: Zorin's own themes recoloured to the Byte palette (rebuilt on
# every HardPoint update and whenever Zorin updates its themes)
for v in Dark Light; do
    if [[ -d /usr/share/themes/ZorinBlue-$v ]]; then
        python3 "$D/make-theme.py" "/usr/share/themes/ZorinBlue-$v" "/usr/share/themes/HardPoint-$v" "${v,,}" ||
            warn "HardPoint-$v theme could not be built"
    fi
done
# HardPoint icon themes: modern Papirus icons, plus the HardPoint logo icons (menu button
# etc.) linked from Zorin's icon themes, where rebrand/apply-logos put our logo
for v in Dark Light; do
    src=/usr/share/icons/ZorinBlue-$v dst=/usr/share/icons/HardPoint-$v
    pap=Papirus-Dark; [[ $v == Light ]] && pap=Papirus
    [[ -f $src/index.theme && -d /usr/share/icons/$pap ]] || continue
    rm -rf "$dst"; mkdir -p "$dst"
    sed -e "s/^Name=.*/Name=HardPoint-$v/" -e "s/^Inherits=.*/Inherits=$pap,ZorinBlue-$v,hicolor/" \
        -e "s/^Comment=.*/Comment=HardPoint OS icons (Papirus with HardPoint logos)/" "$src/index.theme" > "$dst/index.theme"
    grep -q '^Inherits=' "$dst/index.theme" || sed -i "/^Name=/a Inherits=$pap,ZorinBlue-$v,hicolor" "$dst/index.theme"
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"; mkdir -p "$dst/$(dirname "$rel")"; ln -sfn "$f" "$dst/$rel"
    done < <(find "$src" \( -type f -o -type l \) \( -iname '*zorin*' -o -iname 'start-here*' -o -iname 'distributor-logo*' \
                -o -iname '*logo*' \) \( -iname '*.png' -o -iname '*.svg' \) ! -name '*.zorin' -print0)
done
GTK="$(pick_theme HardPoint-Dark ZorinPurple-Dark ZorinBlue-Dark Yaru-purple-dark Adwaita-dark || true)"
ICONS="$(pick_icons HardPoint-Dark Papirus-Dark ZorinPurple-Dark ZorinBlue-Dark Yaru-purple-dark Adwaita || true)"
log "Theme: ${GTK:-default}, icons: ${ICONS:-default}"
mkdir -p /etc/dconf/db/local.d /etc/dconf/db/gdm.d /etc/dconf/profile
{
    echo "# HardPoint OS defaults (users can change all of these)"
    echo "[org/gnome/desktop/background]"
    echo "picture-uri='file:///usr/share/backgrounds/hardpoint/byte-light.jpg'"
    echo "picture-uri-dark='file:///usr/share/backgrounds/hardpoint/byte-dark.jpg'"
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
    echo "[org/gnome/shell/extensions/user-theme]"
    [[ -n $GTK ]] && echo "name='$GTK'"
    echo
    echo "[org/gnome/mutter]"
    echo "center-new-windows=true"
    echo
    echo "# Alt+Space = quick search (apps, files, settings, calculator), like PowerToys Run / Spotlight"
    echo "[org/gnome/shell/keybindings]"
    echo "toggle-overview=['<Alt>space', '<Super>s']"
    echo
    echo "[org/gnome/desktop/wm/keybindings]"
    echo "activate-window-menu=['<Alt>F3']"
    echo
    echo "# Terminal: Ctrl+V pastes like everywhere else (Ctrl+Shift+V still works)"
    echo "[org/gnome/terminal/legacy/keybindings]"
    echo "paste='<Primary>v'"
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
picture-uri='file:///usr/share/backgrounds/hardpoint/byte-light.jpg'
picture-uri-dark='file:///usr/share/backgrounds/hardpoint/byte-dark.jpg'

[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/hardpoint/login.png'

[org.gnome.desktop.interface]
color-scheme='prefer-dark'
${GTK:+gtk-theme='$GTK'}
${ICONS:+icon-theme='$ICONS'}

[org.gnome.shell.keybindings]
toggle-overview=['<Alt>space', '<Super>s']

[org.gnome.desktop.wm.keybindings]
activate-window-menu=['<Alt>F3']
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

# ------------------------------------------------------------ security
log "Applying security defaults"
sed -i 's/^ENABLED=.*/ENABLED=yes/' /etc/ufw/ufw.conf 2>/dev/null || true
sed -i 's/^DEFAULT_INPUT_POLICY=.*/DEFAULT_INPUT_POLICY="DROP"/; s/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="DROP"/' /etc/default/ufw 2>/dev/null || true
for u in ufw.service apparmor.service fwupd-refresh.timer hardpoint-firstboot.service hardpoint-touchpad.service hardpoint-boot.service thermald.service; do
    systemctl enable "$u" >/dev/null 2>&1 || warn "Could not enable $u"
done
systemctl disable usbguard.service 2>/dev/null || true   # only on in Lockdown Mode
# Battery limit + system info now (not while building the ISO)
[[ -z ${HP_STAGE:-} ]] && { /usr/lib/hardpoint/hp-boot || true; }
[[ -f /etc/usbguard/usbguard-daemon.conf ]] && sed -i 's/^IPCAllowedGroups=.*/IPCAllowedGroups=sudo/' /etc/usbguard/usbguard-daemon.conf
# No crash dumps, no core files
mkdir -p /etc/security/limits.d && echo "* hard core 0" > /etc/security/limits.d/90-hardpoint.conf
sed -i 's/^enabled=1/enabled=0/' /etc/default/apport 2>/dev/null || true
# Compressed RAM swap
printf '[zram0]\nzram-size = min(ram / 2, 8192)\ncompression-algorithm = zstd\n' > /etc/systemd/zram-generator.conf
# Installed system: hide the GRUB menu unless Shift/Esc is held, HardPoint background
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/90-hardpoint.cfg <<'EOF'
# Menu shows for 3 s so you can pick Windows on the other SSD (found by os-prober)
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=3
GRUB_DISABLE_OS_PROBER=false
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
bash "$D/rebrand.sh"
if [[ -s $S/logo-targets.txt ]]; then
    python3 "$D/apply-logos.py" / "$S/logo-targets.txt" /usr/share/hardpoint/branding || warn "Logo replacement had problems"
fi
for d in /usr/share/icons/*/; do
    if [[ -f $d/index.theme ]]; then gtk-update-icon-cache -qf "$d" 2>/dev/null || true; fi
done
bash "$D/gdm-theme.sh" || warn "Login screen theme could not be applied"

# Boot splash
if [[ -d /usr/share/plymouth/themes/hardpoint ]]; then
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
        /usr/share/plymouth/themes/hardpoint/hardpoint.plymouth 300
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/hardpoint/hardpoint.plymouth
    # Zorin also names its theme in plymouthd.conf, which wins over the alternative
    mkdir -p /etc/plymouth
    printf '[Daemon]\nTheme=hardpoint\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf
    if command -v plymouth-set-default-theme >/dev/null; then plymouth-set-default-theme hardpoint || true; fi
    log "Boot splash: $(plymouth-set-default-theme 2>/dev/null || readlink -f /etc/alternatives/default.plymouth)"
fi
# Touchpad driver order applies inside the boot image too
grep -qx 'pinctrl_alderlake' /etc/initramfs-tools/modules 2>/dev/null || printf 'pinctrl_alderlake\npinctrl_tigerlake\n' >> /etc/initramfs-tools/modules
log "Rebuilding the boot image"
if [[ ${HP_SKIP_INITRAMFS:-} != 1 ]]; then
    update-initramfs -u -k all >/dev/null 2>&1 || warn "update-initramfs reported a problem"
fi
# Show which splash ended up inside the boot image (build log check)
for i in /boot/initrd.img-*; do
    log "$(basename "$i"): $(lsinitramfs "$i" 2>/dev/null | grep -oE 'plymouth/themes/[^/]+' | sort -u | tr '\n' ' ')" | tee -a "$S/build-report.txt"
done

# Zorin's own welcome tour also opens at first sign-in; HardPoint Setup replaces it
for f in /etc/xdg/autostart/*.desktop; do
    [[ -f $f ]] || continue
    case "$(basename "$f")" in hardpoint-*) continue ;; esac
    if grep -qiE '^Exec=.*zorin.*(tour|welcome|intro)|^Exec=.*(tour|welcome|intro).*zorin' "$f" \
       || { grep -qi zorin "$f" && grep -qiE '^Name(\[[^]]*\])?=.*(tour|welcome)' "$f"; }; then
        if ! dpkg-divert --list "$f" | grep -q .; then
            dpkg-divert --quiet --local --rename --divert "$f.zorin" --add "$f"
            cp "$f.zorin" "$f"
        fi
        grep -q '^Hidden=true' "$f" || printf 'Hidden=true\n' >> "$f"
        log "Turned off Zorin's welcome tour ($(basename "$f"))"
    fi
done

# One updater: HardPoint Updates. Hide Zorin/Ubuntu's Software Updater and its
# pop-up notifier (HardPoint Updates covers system, app and firmware updates).
hide_desktop() {  # hide_desktop <file> <key>: NoDisplay for menus, Hidden for autostart
    local f="$1" key="$2"
    [[ -f $f ]] || return 0
    if ! dpkg-divert --list "$f" | grep -q .; then
        dpkg-divert --quiet --local --rename --divert "$f.zorin" --add "$f"
        cp "$f.zorin" "$f"
    fi
    grep -q "^$key=true" "$f" || printf '%s=true\n' "$key" >> "$f"
}
for f in /usr/share/applications/update-manager.desktop /usr/share/applications/zorin-os-upgrader*.desktop \
         /usr/share/applications/*upgrader*.desktop \
         /usr/share/applications/*update-manager*.desktop; do
    [[ -f $f ]] && hide_desktop "$f" NoDisplay && log "Hid $(basename "$f") (HardPoint Updates replaces it)"
done
for f in /etc/xdg/autostart/update-notifier.desktop /etc/xdg/autostart/*zorin*upgrade*.desktop; do
    [[ -f $f ]] && hide_desktop "$f" Hidden && log "Turned off $(basename "$f")"
done

# Local admins stay admins no matter what manages the "sudo" group
bash "$D/admins.sh"
log "HardPoint settings applied"
