#!/usr/bin/env bash
# Prepare a GitHub Release from a built ISO: split it into parts GitHub accepts
# (2 GB per file max), write checksums, a one-command download script and the notes.
#   make-release.sh <iso> <tag> <out-dir>
set -euo pipefail
ISO="$1" TAG="$2" OUT="$3"
REPO="${GITHUB_REPOSITORY:-Shanes-usernam3/Hardpoint-OS-Ubuntu}"
NAME="$(basename "$ISO")"
BASE="https://github.com/$REPO/releases/download/$TAG"
mkdir -p "$OUT"

SUM="$(sha256sum "$ISO" | awk '{print $1}')"
SIZE="$(du -h "$ISO" | cut -f1)"
split -b 1900M -d -a 2 "$ISO" "$OUT/$NAME.part"
PARTS=()
for p in "$OUT/$NAME".part*; do PARTS+=("$(basename "$p")"); done
(cd "$OUT" && sha256sum "${PARTS[@]}" > SHA256SUMS-parts.txt)
echo "$SUM  $NAME" > "$OUT/SHA256SUMS.txt"

# One command to download, join and verify (works on Linux, Proxmox and WSL)
{
    echo '#!/bin/sh'
    echo "# Downloads HardPoint OS $TAG, joins the parts into $NAME and checks it."
    echo '#   curl -fsSL <this script url> | sh            (saves into the current folder)'
    echo '#   On Proxmox VE, run it from /var/lib/vz/template/iso so the ISO shows up in "local".'
    echo 'set -e'
    echo "NAME=\"$NAME\""
    echo "BASE=\"$BASE\""
    echo "SUM=\"$SUM\""
    echo 'echo "Downloading $NAME ('"$SIZE"') in '"${#PARTS[@]}"' parts..."'
    echo ': > "$NAME.tmp"'
    for p in "${PARTS[@]}"; do
        echo "curl -fL --retry 3 \"\$BASE/$p\" >> \"\$NAME.tmp\""
    done
    echo 'echo "Checking..."'
    echo 'if [ "$(sha256sum "$NAME.tmp" | cut -d" " -f1)" = "$SUM" ]; then mv "$NAME.tmp" "$NAME"; echo "OK: $(pwd)/$NAME"; else rm -f "$NAME.tmp"; echo "Checksum mismatch - download again." >&2; exit 1; fi'
} > "$OUT/get-hardpoint-iso.sh"
chmod 755 "$OUT/get-hardpoint-iso.sh"

VER="${TAG#v}"
cat > "$OUT/notes.md" <<EOF
**HardPoint OS $VER — Zorin Edition** (based on Zorin OS 18 Core / Ubuntu 24.04 LTS). Built by HardPoint Networks.

Byte-style HardPoint Dark theme, HardPoint apps (Setup, Updates, Accounts, Security, System), Microsoft Entra ID sign-in + Intune Company Portal, dev / IT / gaming tools, Steam, automatic snapshot before every update, and updates delivered without reinstalling.

## Download

The ISO is $SIZE, so it is split into ${#PARTS[@]} parts (GitHub's 2 GB file limit). One command downloads, joins and verifies it:

\`\`\`sh
curl -fsSL $BASE/get-hardpoint-iso.sh | sh
\`\`\`

**Proxmox VE** — in the node's **Shell**, run it from the ISO folder so it appears under *local → ISO Images*:

\`\`\`sh
cd /var/lib/vz/template/iso && curl -fsSL $BASE/get-hardpoint-iso.sh | sh
\`\`\`

**Windows** — download all \`.part\` files below into one folder, then in that folder run (Command Prompt):

\`\`\`
copy /b $(printf '%s+' "${PARTS[@]}" | sed 's/+$//') $NAME
certutil -hashfile $NAME SHA256
\`\`\`

SHA-256 of the ISO: \`$SUM\`

## Proxmox VE virtual machine settings

| Setting | Value |
|---|---|
| OS | Linux 6.x kernel, ISO: \`$NAME\` |
| System | Machine **q35**, BIOS **OVMF (UEFI)**, add EFI disk (pre-enrolled keys on = Secure Boot works), **Qemu Agent on** |
| Disk | VirtIO SCSI single, **64 GB+**, Discard + SSD emulation on |
| CPU | **host**, 4 cores |
| Memory | **8192 MB** (4096 minimum) |
| Network | VirtIO |
| Display | VirtIO-GPU (or SPICE for clipboard sharing) |

Boot the VM, choose **Try or Install HardPoint OS**, then **Install HardPoint OS** on the desktop. The guest agent is preinstalled, so Proxmox shows the VM's IP and can shut it down cleanly.

## Real PCs

Write the ISO with Rufus (GPT, UEFI) or balenaEtcher. Secure Boot can stay on.

## Already running HardPoint OS?

No reinstall needed — **HardPoint Updates** brings installed PCs up to date.
EOF
echo "Release files in $OUT:"; ls -lh "$OUT"
