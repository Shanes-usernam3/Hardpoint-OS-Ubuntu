#!/usr/bin/env bash
# HardPoint OS — list every place upstream branding can still be seen.
#   audit-branding.sh            (run as root for full results; read-only)
# Used by the ISO build (output goes to the build report) and on installed PCs.
set -uo pipefail
export LC_ALL=C
UP='kubuntu'

hidden() { grep -qiE '^(NoDisplay|Hidden)=true' "$1"; }

echo "===== BRANDING AUDIT ($(date -u +%F)) ====="

echo "== 1. Visible app launchers with upstream names (menu)"
for f in /usr/share/applications/*.desktop /usr/local/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop; do
    [[ -f $f ]] || continue
    hidden "$f" && continue
    if grep -qiE "^(Name|GenericName|Comment)(\[[^]]*\])?=.*$UP" "$f"; then
        printf '%s | %s\n' "$(basename "$f")" "$(grep -m1 -E '^Name=' "$f" | cut -d= -f2-)"
    fi
done

echo "== 2. Active autostart entries from the base system"
for f in /etc/xdg/autostart/*.desktop; do
    [[ -f $f ]] || continue
    hidden "$f" && continue
    case "$(basename "$f")" in hardpoint-*) continue ;; esac
    printf '%s | %s\n' "$(basename "$f")" "$(grep -m1 -E '^Exec=' "$f" | cut -d= -f2-)"
done

echo "== 3. Upstream branding packages installed"
dpkg-query -W -f='${Package}\t${binary:Summary}\n' '*kubuntu*' 2>/dev/null | sort

echo "== 4. Plasma / installer / login defaults"
echo "      look and feel: $(grep -hs LookAndFeelPackage /usr/share/kubuntu-default-settings/kf5-settings/kdeglobals /etc/xdg/kdeglobals | sort -u | tr '\n' ' ')"
echo "      splash: $(grep -hs '^Theme=' /usr/share/kubuntu-default-settings/kf5-settings/ksplashrc /etc/xdg/ksplashrc | sort -u | tr '\n' ' ')"
echo "      installer branding: $(grep -hs '^branding:' /etc/calamares/settings.conf)"
echo "      login theme: $(grep -hs '^Current=' /etc/sddm.conf.d/*.conf /etc/sddm.conf | tr '\n' ' ')"

echo "== 5. Text files with visible upstream names"
while IFS= read -r -d '' f; do
    hits="$(grep -niE "kubuntu( |['\"<]|$)" "$f" 2>/dev/null | grep -viE 'kubuntu\.org|Copyright|launchpad|kubuntu-devel' | head -3)"
    [[ -n $hits ]] || continue
    echo "-- $f"
    printf '%s\n' "$hits" | cut -c1-160 | sed 's/^/      /'
done < <(find /usr/share/plasma /usr/share/kubuntu-default-settings /etc/calamares /usr/share/sddm /usr/share/plymouth /etc/xdg \
            -xdev -type f \( -name '*.qml' -o -name '*.js' -o -name '*.json' -o -name '*.desc' -o -name '*.conf' \
            -o -name '*rc' -o -name '*.desktop' -o -name '*.plymouth' \) ! -name '*.upstream' -size -2M -print0 2>/dev/null \
            | xargs -0 -r grep -liIZ 'kubuntu' 2>/dev/null)

echo "== 6. System identity"
grep -hE '^(PRETTY_NAME|NAME|ID)=' /etc/os-release 2>/dev/null | sed 's/^/      /'
echo "      lsb: $(grep -h DISTRIB_DESCRIPTION /etc/lsb-release 2>/dev/null)"
echo "      issue: $(head -1 /etc/issue 2>/dev/null)"
echo "      plymouth: $(grep -h '^Theme=' /etc/plymouth/plymouthd.conf 2>/dev/null)"
echo "===== END BRANDING AUDIT ====="
