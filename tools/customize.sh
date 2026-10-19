#!/usr/bin/env bash
# Runs INSIDE the unpacked live system (chroot) during the build.
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
# The installer's own CD-ROM source can't be used inside the build; set it aside until the end
for f in /etc/apt/sources.list.d/cdrom.sources /etc/apt/sources.list.d/cdrom.list; do
    [[ -f $f ]] && mv "$f" "$f.hp-build"
done
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
URIs: https://packages.microsoft.com/ubuntu/26.04/prod
Suites: resolute
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
{ echo "== Packages skipped (not available)"; printf '%s\n' "${SKIP[@]}"; } >> "$S/build-report.txt"

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

# ------------------------------------------------------------ HardPoint package
# Everything HardPoint adds (apps, branding, boot splash, login theme, security
# and laptop settings) lives in the hardpoint-os package. Installing it here runs
# the same setup that later updates run on installed PCs.
export HP_STAGE="$S"
log "Installing the hardpoint-os package"
"${APT[@]}" install "$S"/hardpoint-os_*.deb
dpkg -s hardpoint-os >/dev/null 2>&1 || { warn "hardpoint-os did not install"; exit 1; }

# Flathub for the apps HardPoint Setup offers
flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || warn "Flathub remote not added"

# (Base-system welcome app and update notifier are hidden by the hardpoint-os package, not removed:
#  removing them could pull out the desktop metapackage.)

# Where can upstream branding still be seen? (goes into the build report)
bash /usr/lib/hardpoint/setup/audit-branding.sh >> "$S/build-report.txt" 2>&1 || true

# ------------------------------------------------------------ check the result
# Stop the build (instead of shipping the plain base system) if HardPoint isn't really applied
{
    echo "== Result check"
    grep -h PRETTY_NAME /etc/os-release
    echo "hardpoint-os: $(dpkg-query -W -f='${Version} ${Status}' hardpoint-os 2>&1)"
    echo "diversions: $(dpkg-divert --list | grep -c upstream)"
    grep -hs LookAndFeelPackage /usr/share/kubuntu-default-settings/kf5-settings/kdeglobals /etc/xdg/kdeglobals
    grep -hs '^branding:' /etc/calamares/settings.conf
    grep -hs '^Theme=' /etc/plymouth/plymouthd.conf
} >> "$S/build-report.txt" 2>&1
fail=()
grep -q 'HardPoint' /etc/os-release || fail+=("os-release")
grep -qs 'com.hardpointnetworks.desktop' /etc/xdg/kdeglobals || fail+=("desktop defaults")
[[ ! -f /etc/calamares/settings.conf ]] || grep -q '^branding: hardpoint' /etc/calamares/settings.conf || fail+=("installer branding")
grep -qs '^Theme=hardpoint' /etc/plymouth/plymouthd.conf || fail+=("boot splash")
if ((${#fail[@]})); then
    warn "HardPoint was not fully applied: ${fail[*]} — re-running the setup to show the error"
    HP_SKIP_INITRAMFS=1 bash -x /usr/lib/hardpoint/setup/apply.sh 2>&1 | tail -80 | tee -a "$S/build-report.txt"
    echo "BUILD STOPPED: not applied: ${fail[*]}" >> "$S/build-report.txt"
    exit 1
fi

# ------------------------------------------------------------ boot image
# The live boot uses the initrd built here (it carries the HardPoint boot splash)
KVER="$(ls /lib/modules | sort -V | tail -1)"
if [[ ! -f /boot/initrd.img-$KVER ]]; then
    log "Creating the boot image for $KVER"
    update-initramfs -c -k "$KVER" >/dev/null
fi

# ------------------------------------------------------------ clean up
for f in /etc/apt/sources.list.d/*.hp-build; do [[ -f $f ]] && mv "$f" "${f%.hp-build}"; done
apt-get autoremove -y -q >/dev/null || true
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/hb-sim.txt
mkdir -p /var/lib/apt/lists/partial
log "Customisation complete"
