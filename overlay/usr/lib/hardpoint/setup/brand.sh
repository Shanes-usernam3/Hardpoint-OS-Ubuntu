#!/usr/bin/env bash
# HardPoint OS 2 — replace the base system's names and branding with HardPoint OS.
# Run by the hardpoint-os package (and the image build) on every install/update.
#
# Every file we replace is "diverted" with dpkg-divert first, so later base-system
# package updates write their version next to ours (*.upstream) instead of
# overwriting the HardPoint branding.
set -euo pipefail
S="${HP_STAGE:-/var/lib/hardpoint}"
mkdir -p "$S"
# shellcheck source=/dev/null
source /usr/lib/hardpoint/setup/build.env
B=/usr/share/hardpoint/branding
log() { printf '\e[1;36m  ->\e[0m %s\n' "$*"; }

divert() {  # divert <path>: keep the packaged original as <path>.upstream
    local f="$1"
    if ! dpkg-divert --list "$f" | grep -q .; then
        dpkg-divert --quiet --local --rename --divert "$f.upstream" --add "$f"
    fi
}
orig() {  # orig <path>: the base system's version of a diverted (or not yet diverted) file
    if [[ -e "$1.upstream" ]]; then echo "$1.upstream"; else echo "$1"; fi
}

# ------------------------------------------------------------ OS identity
log "OS identity"
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-resolute}}")"
UBUNTU_VER="$(. "$(orig /usr/lib/os-release)" 2>/dev/null && echo "${VERSION_ID:-26.04}")"
OSREL=/usr/lib/os-release
[[ -L /etc/os-release ]] || OSREL=/etc/os-release
divert "$OSREL"
cat > "$OSREL" <<EOF
PRETTY_NAME="$HP_NAME $HP_BASE_VERSION"
NAME="$HP_NAME"
VERSION_ID="$HP_BASE_VERSION"
VERSION="$HP_BASE_VERSION (based on Ubuntu $UBUNTU_VER LTS)"
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
DISTRIB_DESCRIPTION="$HP_NAME $HP_BASE_VERSION"
EOF
# add-apt-repository / Software Sources look up a template named after DISTRIB_ID
for t in /usr/share/python-apt/templates/Ubuntu.info /usr/share/python-apt/templates/Ubuntu.mirrors; do
    [[ -f $t ]] && cp "$t" "${t/Ubuntu/HardPoint}"
done
for f in /etc/issue /etc/issue.net; do
    [[ -f $f ]] || continue
    divert "$f"
    if [[ $f == /etc/issue ]]; then echo "$HP_NAME $HP_BASE_VERSION \\n \\l"; else echo "$HP_NAME $HP_BASE_VERSION"; fi > "$f"
    echo >> "$f"
done
# Live session: user name and host name
if [[ -f /etc/casper.conf ]]; then
    sed -i -E 's/^(export )?USERNAME=.*/export USERNAME="hardpoint"/; s/^(export )?USERFULLNAME=.*/export USERFULLNAME="HardPoint Live"/; s/^(export )?HOST=.*/export HOST="hardpoint"/; s/^(export )?BUILD_SYSTEM=.*/export BUILD_SYSTEM="Ubuntu"/' /etc/casper.conf
fi

# ------------------------------------------------------------ "Kubuntu" in app names
log "Renaming base-system launchers"
SUBST='s/Kubuntu [0-9.]+( LTS)?/HardPoint OS/g; s/Kubuntu/HardPoint OS/g'
for f in /usr/share/applications/*.desktop /etc/xdg/autostart/*.desktop /usr/share/plasma/look-and-feel/*/metadata.json; do
    [[ -f $f ]] || continue
    src="$(orig "$f")"
    grep -qE '(^|"|=)[^=]*Kubuntu' "$src" || continue
    grep -qE '^(Name|GenericName|Comment|X-GNOME-FullName)(\[[^]]*\])?=.*Kubuntu|"(Name|Description)[^"]*": ".*Kubuntu' "$src" || continue
    divert "$f"
    sed -E "/^(Name|GenericName|Comment|X-GNOME-FullName)(\[[^]]*\])?=/ { $SUBST }; /\"(Name|Description)[^\"]*\": / { $SUBST }" "$f.upstream" > "$f"
done

# ------------------------------------------------------------ Plasma defaults
# Kubuntu keeps its desktop defaults in kubuntu-default-settings (on the XDG config
# path); HardPoint replaces those files so every new account starts as HardPoint.
log "Desktop defaults (HardPoint look, Windows 11 layout)"
K=/usr/share/kubuntu-default-settings/kf5-settings
put() {  # put <file> : write stdin as the default config <file> (diverting the base one)
    local f="$1"
    mkdir -p "$(dirname "$f")"
    [[ -e $f ]] && divert "$f"
    cat > "$f"
}
DEFAULTS_DIRS=(/etc/xdg)
[[ -d $K ]] && DEFAULTS_DIRS=("$K" /etc/xdg)
for d in "${DEFAULTS_DIRS[@]}"; do
    put "$d/kdeglobals" <<'EOF'
[General]
ColorScheme=HardPointDark
XftAntialias=true
XftHintStyle=hintslight
XftSubPixel=rgb
BrowserApplication=microsoft-edge.desktop
AccentColor=69,230,211

[Icons]
Theme=Papirus-Dark

[KDE]
LookAndFeelPackage=com.hardpointnetworks.desktop
AutomaticLookAndFeel=false
DefaultLightLookAndFeel=com.hardpointnetworks.desktop
DefaultDarkLookAndFeel=com.hardpointnetworks.desktop
SingleClick=false
widgetStyle=Breeze
contrast=4
EOF
    put "$d/kcm-about-distrorc" <<EOF
[General]
LogoPath=$B/logo-256.png
Name=$HP_NAME
UseOSReleaseVersion=false
Version=$HP_BASE_VERSION (based on Ubuntu $UBUNTU_VER LTS)
Website=$HP_HOME_URL
Variant=by HardPoint Networks
EOF
    put "$d/kscreenlockerrc" <<'EOF'
[Daemon]
Autolock=true
Timeout=10

[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/wallpapers/HardPoint/
PreviewImage=file:///usr/share/wallpapers/HardPoint/
EOF
    put "$d/ksplashrc" <<'EOF'
[KSplash]
Engine=KSplashQML
Theme=com.hardpointnetworks.desktop
EOF
    put "$d/plasmarc" <<'EOF'
[Theme]
name=default

[Wallpapers]
usersWallpapers=
EOF
    put "$d/kwinrc" <<'EOF'
[Plugins]
overviewEnabled=true
translucencyEnabled=true
wobblywindowsEnabled=false

[org.kde.kdecoration2]
library=org.kde.breeze
theme=Breeze
ButtonsOnLeft=
ButtonsOnRight=IAX

[Windows]
RollOverDesktops=true

[Effect-overview]
BorderActivate=9
EOF
    # Windows keyboard shortcuts on top of Plasma's (Win, Win+E, Win+L, Win+D, Win+V,
    # Win+Shift+S, Alt+Tab and Alt+Space already match Windows in Plasma)
    put "$d/kglobalshortcutsrc" <<'EOF'
[services][org.kde.plasma-systemmonitor.desktop]
_launch=Ctrl+Shift+Esc

[services][systemsettings.desktop]
_launch=Meta+I

[services][org.kde.krunner.desktop]
_launch=Alt+Space\tMeta+S\tAlt+F2
EOF
    put "$d/dolphinrc" <<'EOF'
[General]
ShowFullPath=false
RememberOpenedTabs=false
ShowStatusBar=true

[DetailsMode]
PreviewSize=22
EOF
done
# Discover's own update pop-ups: HardPoint Updates covers system, app and firmware updates
put /etc/xdg/discoverabstractnotifier.notifyrc <<'EOF'
[Event/Update]
Action=
[Event/UpdateWithAction]
Action=
EOF

# ------------------------------------------------------------ login screen (SDDM)
log "Login screen"
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/zz-hardpoint.conf <<'EOF'
# HardPoint OS login screen
[Theme]
Current=breeze
CursorTheme=breeze_cursors
EOF
if [[ -d /usr/share/sddm/themes/breeze ]]; then
    cat > /usr/share/sddm/themes/breeze/theme.conf.user <<'EOF'
[General]
type=image
background=/usr/share/backgrounds/hardpoint/login.png
EOF
fi

# ------------------------------------------------------------ installer (Calamares)
if [[ -f /etc/calamares/settings.conf ]]; then
    log "Installer branding"
    divert /etc/calamares/settings.conf
    sed -E 's/^branding:.*/branding: hardpoint/' /etc/calamares/settings.conf.upstream > /etc/calamares/settings.conf
    W=/etc/calamares/modules/welcome.conf
    if [[ -f $W ]]; then
        divert "$W"
        sed -E "s|^showDonateUrl:.*|showDonateUrl: false|; s|^showSupportUrl:.*|showSupportUrl: false|; s|^showKnownIssuesUrl:.*|showKnownIssuesUrl: false|; s|^showReleaseNotesUrl:.*|showReleaseNotesUrl: false|" "$W.upstream" > "$W"
    fi
fi

# ------------------------------------------------------------ live USB session
# The base image starts a "Try or Install" chooser with its own logo. HardPoint goes straight to
# the desktop (like Windows setup media would show you the PC), with Install HardPoint OS on it.
LIVE=/usr/libexec/start-kubuntu-live-env
if [[ -f $LIVE || -f $LIVE.upstream ]]; then
    log "Live session"
    divert "$LIVE"
    cat > "$LIVE" <<'EOF'
#!/bin/bash
# HardPoint OS live session (USB stick): desktop with the installer on it.
export XDG_SESSION_CLASS="user" XDG_SESSION_DESKTOP="KDE" DESKTOP_SESSION="plasma" QT_QPA_PLATFORMTHEME="kde"
if [[ $(cat /proc/cmdline) =~ "oem-config/enable=true" ]]; then
    kwin_wayland --xwayland --no-lockscreen /usr/bin/calamares-launch-oem
fi
mkdir -p "$HOME/Desktop"
cat > "$HOME/Desktop/install-hardpoint-os.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Install HardPoint OS
Comment=Install HardPoint OS on this PC
Icon=hardpoint
Exec=sudo /usr/bin/calamares-launch-normal
DESK
chmod +x "$HOME/Desktop/install-hardpoint-os.desktop"
exec startplasma-wayland
EOF
    chmod 755 "$LIVE"
    S_LIVE=/usr/share/wayland-sessions/kubuntu-live-environment.desktop
    if [[ -f $S_LIVE ]]; then
        divert "$S_LIVE"
        sed -E 's/Kubuntu/HardPoint OS/g' "$S_LIVE.upstream" > "$S_LIVE"
    fi
fi

# ------------------------------------------------------------ boot splash
# Hide the base system's splash themes so ours is the only choice
for t in /usr/share/plymouth/themes/kubuntu-logo /usr/share/plymouth/themes/kubuntu-text; do
    [[ -d $t ]] || continue
    for f in "$t"/*.plymouth; do
        [[ -f $f ]] && update-alternatives --remove default.plymouth "$f" >/dev/null 2>&1 || true
    done
done

# ------------------------------------------------------------ welcome app, tour, notifier
log "Hiding the base system's welcome app and update notifier (HardPoint Setup / Updates replace them)"
hide() {  # hide <desktop file> <key>
    local f="$1" key="$2"
    [[ -f $f && $f != *.upstream ]] || return 0
    divert "$f"; cp "$f.upstream" "$f"
    grep -q "^$key=true" "$f" || printf '%s=true\n' "$key" >> "$f"
}
for f in /etc/xdg/autostart/org.kde.plasma-welcome.desktop /etc/xdg/autostart/org.kde.discover.notifier.desktop \
         /etc/xdg/autostart/kubuntu-*.desktop /etc/xdg/autostart/*notification-helper*.desktop; do
    hide "$f" Hidden
done
for f in /usr/share/applications/org.kde.plasma-welcome.desktop /usr/share/applications/*kubuntu*welcome*.desktop; do
    hide "$f" NoDisplay
done

# ------------------------------------------------------------ build report
if [[ -n ${HP_STAGE:-} ]]; then
    {
        echo "== Branding"
        grep -h PRETTY_NAME /etc/os-release
        echo "Calamares branding: $(grep -h '^branding:' /etc/calamares/settings.conf 2>/dev/null)"
        echo "Default look: $(grep -h LookAndFeelPackage "$K/kdeglobals" /etc/xdg/kdeglobals 2>/dev/null | sort -u | tr '\n' ' ')"
    } >> "$S/build-report.txt"
fi
log "HardPoint branding applied"
