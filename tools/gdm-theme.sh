#!/usr/bin/env bash
# Runs INSIDE the chroot. Builds the HardPoint (Byte style) login screen theme:
# takes the GNOME Shell theme GDM uses, appends HardPoint CSS and registers the
# result as the login-screen theme.
set -euo pipefail
log() { printf '\e[1;36m  ->\e[0m %s\n' "$*"; }
export DEBIAN_FRONTEND=noninteractive

SRC=""
if update-alternatives --query gdm-theme.gresource >/dev/null 2>&1; then
    SRC="$(update-alternatives --query gdm-theme.gresource | awk '/^Value:/ {print $2}')"
fi
for c in "$SRC" /usr/share/gnome-shell/gnome-shell-theme.gresource /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource; do
    [[ -n $c && -f $c ]] && { SRC="$(readlink -f "$c")"; break; }
done
[[ -f $SRC ]] || { echo "No GNOME Shell theme resource found"; exit 1; }
log "Login screen theme base: $SRC"

NEED=()
command -v gresource >/dev/null || NEED+=(libglib2.0-bin)
command -v glib-compile-resources >/dev/null || NEED+=(libglib2.0-dev-bin)
((${#NEED[@]} == 0)) || apt-get install -y -q --no-install-recommends "${NEED[@]}" >/dev/null

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
PREFIX=""
while read -r r; do
    mkdir -p "$W/$(dirname "$r")"
    gresource extract "$SRC" "$r" > "$W/$r"
    [[ -z $PREFIX ]] && PREFIX="$(dirname "$r")"
done < <(gresource list "$SRC")

CSS="$(cat <<'EOF'

/* ===== HardPoint OS login screen (Byte style) ===== */
#lockDialogGroup {
  background: #0A0E17 url("file:///usr/share/backgrounds/hardpoint/login.png");
  background-size: cover;
  background-position: center;
}
.login-dialog, .unlock-dialog { background-color: transparent; color: #F2F4FF; }
.login-dialog-logo-bin { padding: 24px 0; }
.login-dialog-user-list { spacing: 8px; }
.login-dialog-user-list-view { min-width: 340px; }
.login-dialog-user-list .login-dialog-user-list-item,
.user-widget-label { color: #F2F4FF; }
.login-dialog-user-list-item {
  border-radius: 18px;
  padding: 10px 14px;
  background-color: rgba(29, 36, 54, 0.55);
  border: 1px solid rgba(112, 109, 252, 0.25);
  transition-duration: 160ms;
}
.login-dialog-user-list-item:hover,
.login-dialog-user-list-item:focus {
  background-color: rgba(112, 109, 252, 0.28);
  border-color: rgba(3, 244, 212, 0.65);
}
.login-dialog-user-list-item:logged-in { border-right: 3px solid #03F4D4; }
.user-icon {
  border: 2px solid rgba(3, 244, 212, 0.75);
  box-shadow: 0 0 18px rgba(112, 109, 252, 0.55);
}
.login-dialog StEntry, .unlock-dialog StEntry, .login-dialog-prompt-entry {
  border-radius: 14px;
  padding: 10px 14px;
  background-color: rgba(10, 14, 23, 0.72);
  border: 1px solid rgba(112, 109, 252, 0.55);
  color: #FFFFFF;
  caret-color: #03F4D4;
  selection-background-color: #706DFC;
}
.login-dialog StEntry:focus, .unlock-dialog StEntry:focus, .login-dialog-prompt-entry:focus {
  border: 2px solid #03F4D4;
  box-shadow: 0 0 16px rgba(3, 244, 212, 0.45);
}
.login-dialog-prompt-label, .login-dialog-message, .login-dialog-not-listed-label { color: #B8BEDD; }
.login-dialog-not-listed-label:hover, .login-dialog-not-listed-button:focus .login-dialog-not-listed-label { color: #03F4D4; }
.login-dialog .button, .unlock-dialog .button, .login-dialog .modal-dialog-button {
  border-radius: 14px;
  padding: 8px 18px;
  color: #FFFFFF;
  background-color: rgba(29, 36, 54, 0.8);
  border: 1px solid rgba(112, 109, 252, 0.35);
}
.login-dialog .button:default, .login-dialog .button.default,
.login-dialog .button:focus, .unlock-dialog .button:focus {
  background-gradient-direction: horizontal;
  background-gradient-start: #03F4D4;
  background-gradient-end: #FF2E96;
  color: #0A0E17;
  font-weight: bold;
  border: none;
}
.login-dialog-session-list-button, .login-dialog-button.cancel-button,
.login-dialog-button.switch-user-button { color: #B8BEDD; border-radius: 999px; }
.login-dialog-session-list-button:hover { color: #03F4D4; }
.login-dialog-banner { color: #B8BEDD; }
.unlock-dialog-clock-time, .login-dialog .clock-time {
  font-weight: 300;
  color: #FFFFFF;
  text-shadow: 0 0 22px rgba(112, 109, 252, 0.9);
}
.unlock-dialog-clock-date { color: #B8BEDD; }
.login-dialog .spinner, .unlock-dialog .spinner { color: #03F4D4; }
#panel.login-screen, #panel.unlock-screen, #panel.lock-screen { background-color: transparent; }
.caps-lock-warning-label, .login-dialog-message-warning { color: #FF2E96; }
EOF
)"

n=0
while IFS= read -r -d '' f; do
    printf '%s\n' "$CSS" >> "$f"
    n=$((n + 1))
done < <(find "$W" -name 'gnome-shell*.css' -print0)
((n > 0)) || { echo "No gnome-shell CSS inside $SRC"; exit 1; }
log "Styled $n stylesheet(s)"

{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<gresources>'
    echo "  <gresource prefix=\"$PREFIX\">"
    (cd "$W$PREFIX" && find . -type f | sed 's|^\./||' | sort | while read -r f; do echo "    <file>$f</file>"; done)
    echo '  </gresource>'
    echo '</gresources>'
} > "$W/hp.xml"
# glib-compile-resources expects all files under one prefix
if [[ $(gresource list "$SRC" | grep -vc "^$PREFIX/") -ne 0 ]]; then
    echo "Theme resources use several prefixes — not supported"; exit 1
fi

OUTDIR=/usr/share/gnome-shell/theme/HardPoint
mkdir -p "$OUTDIR"
glib-compile-resources --sourcedir="$W$PREFIX" --target="$OUTDIR/gdm-theme.gresource" "$W/hp.xml"

if update-alternatives --query gdm-theme.gresource >/dev/null 2>&1; then
    update-alternatives --install /usr/share/gnome-shell/gdm-theme.gresource gdm-theme.gresource "$OUTDIR/gdm-theme.gresource" 300
    update-alternatives --set gdm-theme.gresource "$OUTDIR/gdm-theme.gresource"
    log "Login screen theme registered (alternatives)"
else
    T=/usr/share/gnome-shell/gnome-shell-theme.gresource
    [[ "$(readlink -f "$T")" == "$SRC" ]] || T="$SRC"
    dpkg-divert --list "$T" | grep -q . || dpkg-divert --quiet --local --rename --divert "$T.zorin" --add "$T"
    cp "$OUTDIR/gdm-theme.gresource" "$T"
    log "Login screen theme installed over $T (original kept as .zorin)"
fi

((${#NEED[@]} == 0)) || apt-get purge -y -q "${NEED[@]}" >/dev/null 2>&1 || true
