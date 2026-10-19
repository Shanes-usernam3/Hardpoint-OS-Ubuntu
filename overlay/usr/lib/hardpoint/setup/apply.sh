#!/usr/bin/env bash
# HardPoint OS 2 — apply HardPoint settings and branding to this system.
# Run by the hardpoint-os package every time it is installed or updated (and by
# the ISO build), so every fix pushed to GitHub reaches installed PCs as a
# normal update. Safe to run again: each step checks or replaces what is there.
set -euo pipefail
D=/usr/lib/hardpoint/setup
S="${HP_STAGE:-/var/lib/hardpoint}"
mkdir -p "$S"
log() { printf '  -> %s\n' "$*"; }
warn() { printf '  WARN: %s\n' "$*" >&2; }

# ------------------------------------------------------------ branding + desktop defaults
bash "$D/brand.sh" || warn "Branding had problems"
for d in /usr/share/icons/*/; do
    if [[ -f $d/index.theme ]]; then gtk-update-icon-cache -qf "$d" 2>/dev/null || true; fi
done
# GTK apps (Edge, Steam, Timeshift...) follow the HardPoint colours through Breeze GTK
mkdir -p /etc/gtk-3.0 /etc/gtk-4.0
for v in 3.0 4.0; do
    cat > /etc/gtk-$v/settings.ini <<'EOF'
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=Papirus-Dark
gtk-application-prefer-dark-theme=true
gtk-font-name=Noto Sans 10
EOF
done

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
# Installed system: short GRUB menu (pick Windows on another drive), HardPoint background
mkdir -p /etc/default/grub.d
cat > /etc/default/grub.d/90-hardpoint.cfg <<'EOF'
# Menu shows for 3 s so you can pick Windows on the other SSD (found by os-prober)
GRUB_DISTRIBUTOR="HardPoint OS"
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=3
GRUB_DISABLE_OS_PROBER=false
GRUB_BACKGROUND="/usr/share/hardpoint/branding/grub.png"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
EOF

# ------------------------------------------------------------ updates
log "Configuring HardPoint Updates"
# apt downloads in the background but never installs on its own — you pick in the checklist
cat > /etc/apt/apt.conf.d/52hardpoint-periodic <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::AutocleanInterval "7";
EOF
systemctl --global enable hardpoint-update-check.timer 2>/dev/null || \
    { mkdir -p /etc/systemd/user/timers.target.wants && ln -sf /usr/lib/systemd/user/hardpoint-update-check.timer /etc/systemd/user/timers.target.wants/; }
# Leftovers from HardPoint OS 1 (GNOME based), if this PC was upgraded in place
systemctl --global disable hardpoint-desktop-trust.path 2>/dev/null || true
rm -f /etc/systemd/user/default.target.wants/hardpoint-desktop-trust.path

# ------------------------------------------------------------ boot splash
if [[ -d /usr/share/plymouth/themes/hardpoint ]]; then
    update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
        /usr/share/plymouth/themes/hardpoint/hardpoint.plymouth 300
    update-alternatives --set default.plymouth /usr/share/plymouth/themes/hardpoint/hardpoint.plymouth
    # The base system also names its theme in plymouthd.conf, which wins over the alternative
    mkdir -p /etc/plymouth
    printf '[Daemon]\nTheme=hardpoint\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf
    if command -v plymouth-set-default-theme >/dev/null; then plymouth-set-default-theme hardpoint || true; fi
    log "Boot splash: $(plymouth-set-default-theme 2>/dev/null || readlink -f /etc/alternatives/default.plymouth)"
fi
# The boot image must work on any PC and from a USB stick: include all common storage/USB drivers
# (a boot image made on the build server would otherwise only carry that server's drivers)
mkdir -p /etc/initramfs-tools/conf.d
printf '# HardPoint OS: boot from any disk or USB stick\nMODULES=most\n' > /etc/initramfs-tools/conf.d/zz-hardpoint-modules
# Touchpad driver order applies inside the boot image too
grep -qx 'pinctrl_alderlake' /etc/initramfs-tools/modules 2>/dev/null || printf 'pinctrl_alderlake\npinctrl_tigerlake\n' >> /etc/initramfs-tools/modules
if [[ ${HP_SKIP_INITRAMFS:-} != 1 ]]; then
    log "Rebuilding the boot image"
    update-initramfs -u -k all >/dev/null 2>&1 || warn "update-initramfs reported a problem"
fi
# Show which splash ended up inside the boot image (build log check)
for i in /boot/initrd.img-*; do
    [[ -e $i ]] || continue
    log "$(basename "$i"): $(lsinitramfs "$i" 2>/dev/null | grep -oE 'plymouth/themes/[^/]+' | sort -u | tr '\n' ' ')" | tee -a "$S/build-report.txt"
done

# Local admins stay admins no matter what manages the "sudo" group
bash "$D/admins.sh"
log "HardPoint settings applied"
