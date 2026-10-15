#!/bin/sh
# Connect an existing HardPoint OS (Zorin Edition) install to HardPoint updates.
#   curl -fsSL https://shanes-usernam3.github.io/Hardpoint-OS-Ubuntu/apt/install.sh | sudo sh
set -e
[ "$(id -u)" = 0 ] || { echo "Run with sudo."; exit 1; }
curl -fsSL "https://shanes-usernam3.github.io/Hardpoint-OS-Ubuntu/apt/hardpoint-archive-keyring.gpg" -o /usr/share/keyrings/hardpoint-archive-keyring.gpg
cat > /etc/apt/sources.list.d/hardpoint.sources <<'SRC'
# HardPoint OS updates (hardpoint-os package), signed by HardPoint Networks
Types: deb
URIs: https://shanes-usernam3.github.io/Hardpoint-OS-Ubuntu/apt
Suites: stable
Components: main
Signed-By: /usr/share/keyrings/hardpoint-archive-keyring.gpg
SRC
apt-get update
apt-get install -y -o Dpkg::Options::=--force-confnew hardpoint-os
echo
echo "Done. HardPoint OS updates now arrive in HardPoint Updates like any other update."
