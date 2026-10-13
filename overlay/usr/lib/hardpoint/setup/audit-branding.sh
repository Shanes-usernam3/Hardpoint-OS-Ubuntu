#!/usr/bin/env bash
# HardPoint OS — list every place the name "Zorin" can still be seen.
#   audit-branding.sh            (run as root for full results; read-only)
# Used by the ISO build (output goes to the build report) and on installed PCs.
set -uo pipefail
export LC_ALL=C

hidden() { grep -qiE '^(NoDisplay|Hidden)=true' "$1"; }

echo "===== BRANDING AUDIT ($(date -u +%F)) ====="

echo "== 1. Visible app launchers mentioning Zorin (menu / app grid)"
for f in /usr/share/applications/*.desktop /usr/local/share/applications/*.desktop /var/lib/flatpak/exports/share/applications/*.desktop; do
    [[ -f $f ]] || continue
    hidden "$f" && continue
    if grep -qiE '^(Name|GenericName|Comment|Keywords|Icon|X-GNOME-FullName)(\[[^]]*\])?=.*zorin' "$f"; then
        printf '%s | %s\n' "$(basename "$f")" "$(grep -m1 -E '^Name=' "$f" | cut -d= -f2-)"
        grep -iE '^(Name|GenericName|Comment|Icon)=.*zorin' "$f" | sed 's/^/      /'
    fi
done

echo "== 2. Active autostart entries mentioning Zorin"
for f in /etc/xdg/autostart/*.desktop; do
    [[ -f $f ]] || continue
    hidden "$f" && continue
    grep -qi zorin "$f" && printf '%s | %s | %s\n' "$(basename "$f")" "$(grep -m1 -E '^Name=' "$f" | cut -d= -f2-)" "$(grep -m1 -E '^Exec=' "$f" | cut -d= -f2-)"
done

echo "== 3. Zorin packages installed (decide: keep / hide / remove)"
dpkg-query -W -f='${Package}\t${binary:Summary}\n' 'zorin*' 2>/dev/null | sort

echo "== 4. GNOME Shell extensions with Zorin in their visible name"
for m in /usr/share/gnome-shell/extensions/*/metadata.json; do
    [[ -f $m ]] || continue
    n="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d.get("name",""))' "$m" 2>/dev/null)"
    [[ $n == *Zorin* ]] && echo "$(basename "$(dirname "$m")") | $n"
done

echo "== 5. Text UI files with a visible 'Zorin' word (excluding code identifiers)"
# Lines with "Zorin" followed by a space or end of a quoted string = user-visible text.
while IFS= read -r -d '' f; do
    hits="$(grep -nE "Zorin( |['\"<]|$)" "$f" 2>/dev/null | grep -vE 'zorin\.com|Copyright|@zorinos|Zorin Group|ZorinOS/' | head -3)"
    [[ -n $hits ]] || continue
    echo "-- $f"
    printf '%s\n' "$hits" | cut -c1-160 | sed 's/^/      /'
done < <(find /usr/share /usr/lib/python3/dist-packages /usr/lib/zorin* /usr/libexec /usr/bin /etc/xdg \
            -xdev -type f \( -name '*.ui' -o -name '*.glade' -o -name '*.py' -o -name '*.js' -o -name '*.json' \
            -o -name '*.xml' -o -name '*.policy' -o -name '*.html' -o -name '*.css' -o -name '*.ini' -o -perm -u+x \) \
            ! -name '*.zorin' ! -path '*/doc/*' ! -path '*/man/*' ! -path '*/locale/*' ! -path '*/help/*' \
            ! -path '*/hardpoint/*' -size -2M -print0 2>/dev/null | xargs -0 -r grep -lIZ 'Zorin' 2>/dev/null)

echo "== 6. Binary files containing 'Zorin' text (resources, libraries)"
find /usr/share /usr/lib -xdev -type f \( -name '*.gresource' -o -name '*.so' -o -name '*.so.*' -o -name '*.typelib' \) \
    -size -50M -print0 2>/dev/null | xargs -0 -r grep -l 'Zorin' 2>/dev/null | grep -v '\.zorin$' | head -30

echo "== 7. Help pages / docs (not changed; listed for reference)"
find /usr/share/help -xdev -type d -iname '*zorin*' 2>/dev/null | head -10

echo "== 8. System identity"
grep -hE '^(PRETTY_NAME|NAME|ID)=' /etc/os-release 2>/dev/null | sed 's/^/      /'
echo "      lsb: $(grep -h DISTRIB_DESCRIPTION /etc/lsb-release 2>/dev/null)"
echo "      issue: $(head -1 /etc/issue 2>/dev/null)"
echo "      plymouth: $(grep -h '^Theme=' /etc/plymouth/plymouthd.conf 2>/dev/null)"
echo "      apt sources mentioning zorin (needed for Zorin updates): $(grep -rli zorin /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | tr '\n' ' ')"
echo "===== END BRANDING AUDIT ====="
