#!/usr/bin/env bash
# Publish hardpoint-os .deb files as a signed apt repository on the gh-pages branch
# (served by GitHub Pages at $HP_APT_URL).
#   HP_SIGNING_KEY=<armored private key> tools/publish-apt.sh <deb>...
# Keeps the 5 newest versions so PCs can still fetch a recent one if needed.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -n ${HP_SIGNING_KEY:-} ]] || { echo "HP_SIGNING_KEY is not set — skipping publish."; exit 0; }
(($#)) || { echo "usage: publish-apt.sh <deb>..."; exit 1; }

SITE="$(mktemp -d)"
REMOTE="${HP_PUSH_URL:-$(git -C "$HERE" remote get-url origin)}"
if git -C "$HERE" fetch -q --depth 1 origin gh-pages 2>/dev/null; then
    git -C "$HERE" archive FETCH_HEAD | tar -x -C "$SITE"
fi
A="$SITE/apt"
mkdir -p "$A/pool/main" "$A/dists/stable/main/binary-amd64" "$A/dists/stable/main/binary-all"
cp "$@" "$A/pool/main/"

# Keep the newest 5 versions
mapfile -t debs < <(for f in "$A"/pool/main/hardpoint-os_*.deb; do echo "$(dpkg-deb -f "$f" Version) $f"; done \
    | sort -t' ' -k1,1 -V -r | awk '{print $2}')
for old in "${debs[@]:5}"; do rm -f "$old"; done

cd "$A"
for arch in amd64 all; do
    apt-ftparchive --arch "$arch" packages pool/main > "dists/stable/main/binary-$arch/Packages"
    gzip -9kf "dists/stable/main/binary-$arch/Packages"
done
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin="HardPoint" \
    -o APT::FTPArchive::Release::Label="HardPoint OS" \
    -o APT::FTPArchive::Release::Suite="stable" \
    -o APT::FTPArchive::Release::Codename="stable" \
    -o APT::FTPArchive::Release::Architectures="amd64 all" \
    -o APT::FTPArchive::Release::Components="main" \
    -o APT::FTPArchive::Release::Description="HardPoint OS updates" \
    release dists/stable > dists/stable/Release

export GNUPGHOME; GNUPGHOME="$(mktemp -d)"
printf '%s\n' "$HP_SIGNING_KEY" | gpg --batch --quiet --import
KEY="$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/ {print $10; exit}')"
gpg --batch --yes --default-key "$KEY" --clearsign -o dists/stable/InRelease dists/stable/Release
gpg --batch --yes --default-key "$KEY" -abs -o dists/stable/Release.gpg dists/stable/Release
gpg --export "$KEY" > hardpoint-archive-keyring.gpg
# The key the PCs trust must match the one we sign with
if ! cmp -s hardpoint-archive-keyring.gpg "$HERE/overlay/usr/share/keyrings/hardpoint-archive-keyring.gpg"; then
    echo "WARNING: signing key differs from overlay/usr/share/keyrings/hardpoint-archive-keyring.gpg"
fi
cp "$HERE/repo/install.sh" "$HERE/repo/index.html" "$A/"
touch "$SITE/.nojekyll"
[[ -f $SITE/index.html ]] || cp "$HERE/repo/index.html" "$SITE/index.html"

cd "$SITE"
git init -q -b gh-pages
git config user.name "HardPoint CI"; git config user.email "ci@hardpoint.invalid"
git add -A
git commit -qm "Publish $(basename "$1")"
git push -qf "$REMOTE" gh-pages
echo "Published: $(ls "$A/pool/main" | tr '\n' ' ')"
