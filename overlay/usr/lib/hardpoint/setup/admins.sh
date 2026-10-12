#!/usr/bin/env bash
# Keep every local administrator in the hpadmin group, which nothing else manages.
# Work/school sign-in (Himmelblau) only manages hp-entra-admins, so the account
# created at install always stays an administrator.
set -uo pipefail
groupadd -f -r hpadmin
groupadd -f -r hp-entra-admins
for g in sudo admin; do
    for u in $(getent group "$g" | cut -d: -f4 | tr ',' ' '); do
        uid="$(id -u "$u" 2>/dev/null || echo 0)"
        if ((uid >= 1000 && uid < 60000)) && ! id -nG "$u" | tr ' ' '\n' | grep -qx hpadmin; then
            gpasswd -a "$u" hpadmin >/dev/null && echo "  -> $u is a HardPoint admin"
        fi
    done
done
exit 0
