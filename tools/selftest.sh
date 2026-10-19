#!/usr/bin/env bash
# HardPoint OS self-test — checks that HardPoint's features are installed and working.
# Read-only: changes nothing. Run as your normal user (it asks for your password once
# for the few checks that need admin rights):
#   curl -fsSL https://raw.githubusercontent.com/Shanes-usernam3/Hardpoint-OS-Ubuntu/main/tools/selftest.sh | bash
# The report is saved to ~/hardpoint-selftest.txt
set -uo pipefail
OUT="$HOME/hardpoint-selftest.txt"
pass=0 warn=0 fail=0
G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' N=$'\e[0m'
ok()   { pass=$((pass+1)); printf '%sPASS%s  %s\n' "$G" "$N" "$*"; echo "PASS  $*" >> "$OUT"; }
wn()   { warn=$((warn+1)); printf '%sWARN%s  %s\n' "$Y" "$N" "$*"; echo "WARN  $*" >> "$OUT"; }
bad()  { fail=$((fail+1)); printf '%sFAIL%s  %s\n' "$R" "$N" "$*"; echo "FAIL  $*" >> "$OUT"; }
sec()  { printf '\n== %s\n' "$*"; printf '\n== %s\n' "$*" >> "$OUT"; }
chk()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
gs()   { gsettings get "$@" 2>/dev/null | tr -d "'"; }

: > "$OUT"
echo "HardPoint OS self-test — $(date '+%F %T')" | tee -a "$OUT"
sudo -v 2>/dev/null || echo "(no admin password given: some checks will be skipped)"
SUDO() { sudo -n "$@" 2>/dev/null; }

sec "System"
grep -q HardPoint /etc/os-release && ok "Identifies as $(. /etc/os-release; echo "$PRETTY_NAME")" || bad "os-release is not HardPoint"
v="$(dpkg-query -W -f='${Version}' hardpoint-os 2>/dev/null)"
[[ -n $v ]] && ok "hardpoint-os package $v" || bad "hardpoint-os package not installed"
echo "      kernel $(uname -r), model $(cat /sys/class/dmi/id/product_version 2>/dev/null)" | tee -a "$OUT"
failed="$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
[[ -z $failed ]] && ok "No failed system services" || wn "Failed services: $failed"

sec "Updates"
apt-cache policy hardpoint-os 2>/dev/null | grep -q shanes-usernam3.github.io && ok "Connected to the HardPoint update source" || bad "HardPoint update source missing"
[[ -f /usr/share/keyrings/hardpoint-archive-keyring.gpg ]] && ok "Update signing key present" || bad "Update signing key missing"
systemctl --user is-enabled hardpoint-update-check.timer >/dev/null 2>&1 && ok "Automatic update checks on" || wn "Automatic update checks off"
[[ -f /etc/apt/apt.conf.d/80hardpoint-snapshot ]] && ok "Snapshot-before-update hook installed" || bad "Snapshot hook missing"
if n="$(SUDO timeshift --list 2>/dev/null | grep -cE '^[0-9]+ +>')"; then
    ((n > 0)) && ok "$n system snapshot(s) available" || wn "No snapshots yet (one is made before the next update)"
else wn "Snapshots not checked (needs admin)"; fi

sec "Look"
for t in HardPoint-Dark HardPoint-Light; do [[ -f /usr/share/themes/$t/gtk-3.0/gtk.css ]] && ok "Theme $t built" || bad "Theme $t missing"; done
[[ -f /usr/share/themes/HardPoint-Dark/gnome-shell/gnome-shell.css ]] && ok "Shell theme (menu/panel) built" || bad "Shell theme missing"
[[ -d /usr/share/icons/Papirus-Dark ]] && ok "Papirus icons installed" || bad "Papirus icons missing"
gtk="$(gs org.gnome.desktop.interface gtk-theme)"; ic="$(gs org.gnome.desktop.interface icon-theme)"
[[ $gtk == HardPoint-* ]] && ok "Your theme: $gtk" || wn "Your theme is $gtk (sign out and back in to switch)"
[[ $ic == HardPoint-* || $ic == Papirus* ]] && ok "Your icons: $ic" || wn "Your icons are $ic"
ut="$(gs org.gnome.shell.extensions.user-theme name)"; echo "      shell theme setting: ${ut:-not used}" | tee -a "$OUT"
grep -q '^Theme=hardpoint' /etc/plymouth/plymouthd.conf 2>/dev/null && ok "HardPoint boot splash" || bad "Boot splash not HardPoint"
[[ -f /usr/share/hardpoint/branding/networks-wordmark-dark.png ]] && ok "HardPoint Networks logos installed" || bad "New logos missing"

sec "Keyboard shortcuts"
[[ $(gs org.gnome.shell.keybindings toggle-overview) == *Alt*space* ]] && ok "Alt+Space quick search" || wn "Alt+Space not set: $(gs org.gnome.shell.keybindings toggle-overview)"
p="$(dconf read /org/gnome/terminal/legacy/keybindings/paste 2>/dev/null)"
[[ -z $p || $p == *Primary*v* ]] && ok "Terminal Ctrl+V paste (default)" || wn "Terminal paste is $p"
if command -v gpaste-client >/dev/null; then
    [[ $(gs org.gnome.GPaste show-history) == *Super*v* ]] && ok "Super+V clipboard history" || wn "Clipboard history installed; sign out/in to enable Super+V"
else echo "      clipboard history not installed (optional)" | tee -a "$OUT"; fi

sec "Hardware"
grep -qiE '^N: Name=.*(touchpad|synaptics|elan)' /proc/bus/input/devices && ok "Touchpad detected" || bad "Touchpad not detected"
compgen -G "/sys/class/net/*/wireless" >/dev/null && ok "Wi-Fi adapter" || bad "No Wi-Fi adapter"
grep -qv "no soundcards" /proc/asound/cards 2>/dev/null && ok "Sound card" || bad "No sound card"
[[ -e /dev/dri/renderD128 ]] && ok "GPU acceleration" || bad "No GPU acceleration"
compgen -G "/sys/class/bluetooth/hci*" >/dev/null && ok "Bluetooth" || wn "Bluetooth not found/off"
compgen -G "/dev/video*" >/dev/null && ok "Camera" || wn "Camera not found (privacy shutter?)"
b="$(/usr/lib/hardpoint/hp-battery status 2>/dev/null)"
[[ $b == none* || -z $b ]] && wn "Battery charge limit not supported ($b)" || ok "Battery charge limit supported ($b)"
for f in /sys/class/power_supply/BAT*; do
    [[ -e $f ]] || continue
    full=$(cat "$f/energy_full" 2>/dev/null || cat "$f/charge_full" 2>/dev/null); des=$(cat "$f/energy_full_design" 2>/dev/null || cat "$f/charge_full_design" 2>/dev/null)
    [[ -n $full && -n $des && $des -gt 0 ]] && echo "      battery health $((100*full/des))%, cycles $(cat "$f/cycle_count" 2>/dev/null)" | tee -a "$OUT"
done
[[ -s /var/lib/hardpoint/serial ]] && ok "Serial number available to HardPoint System" || wn "Serial not saved yet (restart once)"
if command -v smartctl >/dev/null; then
    for d in $(lsblk -dnpo PATH,TYPE | awk '$2=="disk" && $1!~/zram|loop/ {print $1}'); do
        h="$(SUDO smartctl -H "$d" | grep -oE 'PASSED|FAILED|OK' | head -1)"
        case "$h" in PASSED|OK) ok "Disk $d healthy";; FAILED) bad "Disk $d FAILING";; *) wn "Disk $d health not checked";; esac
    done
fi
grep -q hardpoint-windows-drive /etc/fstab && ok "Windows drive shown in Files" || echo "      Windows drive not shown (optional)" | tee -a "$OUT"

sec "Security"
chk "Firewall on" systemctl is-active ufw
chk "AppArmor on" systemctl is-active apparmor
lsblk -rno TYPE | grep -qx crypt && ok "Disk encrypted" || wn "Disk not encrypted"
sb="$(mokutil --sb-state 2>/dev/null)"; [[ $sb == *enabled* ]] && ok "Secure Boot on" || wn "Secure Boot: ${sb:-unknown}"
[[ -f /etc/hardpoint/lockdown ]] && echo "      Lockdown Mode ON" | tee -a "$OUT" || echo "      Lockdown Mode off" | tee -a "$OUT"

sec "Accounts"
id -nG | grep -qwE 'sudo|hpadmin|hp-entra-admins' && ok "$(id -un) is an admin" || wn "$(id -un) is not an admin"
if systemctl is-enabled himmelblaud >/dev/null 2>&1; then
    chk "Work/school sign-in service running" systemctl is-active himmelblaud
    echo "      domain: $(grep -m1 '^domain' /etc/himmelblau/himmelblau.conf 2>/dev/null | cut -d= -f2)" | tee -a "$OUT"
else echo "      work/school sign-in not set up" | tee -a "$OUT"; fi
command -v intune-portal >/dev/null && ok "Company Portal installed" || wn "Company Portal missing"
id -nG | grep -qw kvm && ok "In kvm group (VMs, Claude Cowork)" || wn "Not in kvm group: sudo usermod -aG kvm \$USER"

sec "Apps"
for a in steam code microsoft-edge-stable docker timeshift-launcher hardpoint-app claude-desktop; do
    command -v "$a" >/dev/null && ok "$a" || wn "$a not found"
done
flatpak remotes 2>/dev/null | grep -q flathub && ok "Flathub ready" || bad "Flathub missing"
echo "      Flatpak apps: $(flatpak list --app --columns=name 2>/dev/null | tr '\n' ',' | sed 's/,$//')" | tee -a "$OUT"

sec "Branding"
z="$(grep -lE '^Name=.*Zorin' /usr/share/applications/*.desktop 2>/dev/null | xargs -r grep -LE '^(NoDisplay|Hidden)=true' | xargs -r -n1 basename | tr '\n' ' ')"
[[ -z $z ]] && ok "No leftover upstream app names" || wn "Apps with upstream names: $z"

printf '\n%s passed, %s warnings, %s failed\n' "$pass" "$warn" "$fail" | tee -a "$OUT"
echo "Report saved to $OUT"
