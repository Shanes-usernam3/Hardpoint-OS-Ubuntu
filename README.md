# HardPoint OS

HardPoint OS 2 is a desktop operating system based on Ubuntu 26.04 LTS with the KDE Plasma 6
desktop, set up to look and work like Windows 11, with HardPoint branding, a Byte-style setup and login experience, dev/IT/gaming software and
Microsoft Entra ID / Intune support. Built by HardPoint Networks.

An earlier Arch-based version lives in [Hardpoint-os](https://github.com/Shanes-usernam3/Hardpoint-os) (suspended).

## What you get

| Area | Included |
|---|---|
| Look | Byte design language everywhere: navy glass, neon cyan → violet → pink. **HardPoint Dark / Light** colour schemes (`tools/make-colors.py`) with Papirus icons. HardPoint boot splash, sign-in splash, login screen, wallpapers, logos and installer branding. **Windows 11 layout** (Plasma look-and-feel `com.hardpointnetworks.desktop`): centred taskbar and Start, system tray with Wi-Fi/sound/battery/notifications, two-line clock and Show desktop; Windows shortcuts (Win, Win+E/I/D/L/V/A/N, Win+Shift+S, Alt+Tab, Ctrl+Shift+Esc). Drag apps and files to the desktop like on Windows; Recycle Bin on the desktop. |
| HardPoint apps | **Setup** (runs on first sign-in: hardware check, look, account type, apps, extras, security), **Updates**, **Accounts**, **Security**, **System** (PC info, serial + Lenovo warranty, battery and disk health, hardware check, **Fix my PC**) — one smooth WebKit UI, admin actions through polkit |
| Quality of life | Battery charge limit (~80%), Windows SSD shown read-only in Files, Do Not Disturb and Night Light in the tray, **Alt+Space** quick search (KRunner), **Win+V** clipboard history (Klipper) |
| Optional apps | Picked in Setup: LibreOffice, Teams/Outlook web apps, Bitwarden, KeePassXC, Backups (Déjà Dup), Flameshot, Lutris, ProtonUp-Qt, Discord, Sunshine/Moonlight, GitHub Desktop, DBeaver, Insomnia, Distrobox, Netlify CLI, Ventoy, Impression, Bottles, Angry IP Scanner, Kdenlive, Audacity, GIMP and more (`config/flatpaks.list`) |
| Accounts | Local account, or **Work or school (Microsoft Entra ID / Azure AD join)** via [Himmelblau](https://himmelblau-idm.org) — sign in at the login screen with your work email, MFA and a PIN. **Intune**: Microsoft's Company Portal app is preinstalled for enrolment. |
| Laptop drivers | Intel Wi-Fi 6 (AX201), Iris Xe graphics + video acceleration, Alder Lake audio (SOF), I2C touchpads with a boot-time safety check (fixes the ThinkBook 15 G4 IAP touchpad), fingerprint reader support (fprintd), thermald, power profiles, firmware updates (fwupd) |
| Security | Firewall blocking all incoming, AppArmor, kernel hardening (same set as HardPoint OS), private Wi-Fi MAC addresses, no crash dumps, compressed RAM swap, optional full-disk encryption in the installer, **Lockdown Mode** (USB devices blocked until approved, Bluetooth off, debuggers admin-only, io_uring off) |
| Safety net | A Timeshift snapshot of the system (not your files) is taken automatically before every system update — from HardPoint Updates or apt. The newest 5 are kept. Undo a bad update with **Snapshots** in HardPoint Updates (Timeshift), or from the USB stick if the PC won't start. |
| Updates | **HardPoint Updates** checks every 6 hours, notifies you, then shows a checklist of every system / app / firmware update so you choose what installs. Security fixes are flagged. Nothing installs on its own. |
| Dev | VS Code, Git + LFS, build tools, CMake/Ninja, Node.js, Python + pipx, OpenJDK 21 + 25, adb/fastboot, Docker + Compose, Podman, QEMU/KVM + virt-manager, ShellCheck. Android Studio in Setup. |
| IT tools | nmap, Wireshark, tcpdump, iperf3, mtr, dig, Remmina (RDP/VNC), FreeRDP, WireGuard/OpenVPN, SMART/NVMe tools, GParted, TestDisk, ddrescue, stress-ng, memtester, fio, hwinfo, inxi. RustDesk in Setup. |
| Gaming | Steam, GameMode, MangoHud, Vulkan (32 + 64-bit), **Xbox Cloud Gaming** launcher (Edge) — plus Greenlight, RetroArch, Dolphin, PCSX2, PPSSPP, mGBA, melonDS, Cemu, DuckStation, Heroic offered in Setup |
| Browser | Microsoft Edge (needed for Intune sign-in and Xbox Cloud Gaming) and Brave |

## Licensing

Open-source components are used under their own licences; credits and licence notes are in
[NOTICE.md](NOTICE.md). HardPoint branding replaces the base system's names, logos, boot splash,
login theme and installer slideshow (`overlay/usr/lib/hardpoint/setup/brand.sh`); replaced files are
kept beside ours with `dpkg-divert`, so upstream updates never bring the old branding back.

## 1. Build the ISO (no commands needed)

Every push to `main` builds a new ISO with GitHub Actions (about 60–90 minutes).

1. Open **Actions → Build HardPoint OS ISO** (or click **Run workflow**).
2. When the run is green, download **hardpoint-os-iso** (a zip with the `.iso` and `SHA256SUMS`).
3. The **Test in a VM** job then boots the ISO, opens the HardPoint apps, installs it onto a test disk
   (`tools/host-install.sh`) and boots it. Screenshots and `summary.md` go to the `test-results` branch.

Local build (Ubuntu 24.04, ~40 GB free): `sudo ./build.sh` → `out/`.
Without Himmelblau packages in `extra-pkgs/` the ISO still builds, just without work/school sign-in.

## Official releases

**Actions → Build HardPoint OS ISO → Run workflow**, type a version
(e.g. `1.1.0`) and run. GitHub builds the ISO, tests it in a VM and, if the test passes,
publishes it on the **Releases** page as `v1.1.0`. (Pushing a `v1.1.0` git tag does the same.)

The ISO is over GitHub's 2 GB file limit, so the release holds it in parts plus
`get-hardpoint-iso.sh`, which downloads, joins and verifies it in one command
(the release notes show it, including the Proxmox VE version). `tools/make-release.sh` makes these files.

## 2. Make the USB with Rufus

1. Pick the USB stick and the `hardpoint-os-*.iso`.
2. Partition scheme **GPT**, target **UEFI (non CSM)**.
3. When Rufus asks, **ISO Image mode** is fine for this edition (DD mode also works).

Secure Boot can stay **on** — this edition uses Ubuntu's signed boot chain.

## 3. Install

1. Boot the USB, pick **Try or Install HardPoint OS**.
2. Double-click **Install HardPoint OS**. On the disk screen choose **Advanced features → Encrypt the new installation** for full-disk encryption (recommended).
3. Restart, sign in. **HardPoint Setup** opens: pick your look, account type and apps, and check the security settings.

## Work or school sign-in (Microsoft Entra ID) and Intune

1. In the Entra admin center, **Devices → Device settings → "Users may join devices to Microsoft Entra"** must include the people who will sign in.
2. Open **HardPoint Accounts** (or the Account step in Setup), choose **Work or school**, enter your domain. Optionally restrict admins / who can sign in with Entra group Object IDs.
3. Sign out. On the login screen choose **Not listed?**, type your work email, approve MFA and create a PIN.
4. **Intune:** signed in as the work user, open **Company Portal** and sign in to enrol the PC.

Notes:
- The local account you made during install always keeps working (and stays admin).
- Microsoft officially supports Intune on Ubuntu. HardPoint OS 2 is Ubuntu 26.04 underneath, but it
  identifies itself as HardPoint OS, so a compliance policy that only *allows* the "Ubuntu"
  distribution will mark it non-compliant. Leave the allowed-distribution setting empty for these devices.
- Conditional Access rules that require MFA work. Rules that require a compliant device work once the PC is enrolled and compliant.
- The Himmelblau version is pinned in `.github/workflows/build-iso.yml` (`HIMMELBLAU_TAG`).

## Updates without reinstalling

Everything HardPoint adds lives in one package, **hardpoint-os** (apps, branding, boot splash,
login theme, security and laptop settings). Every push to `main` builds a new version and
publishes it, signed, to the HardPoint update source on GitHub Pages
(`https://shanes-usernam3.github.io/Hardpoint-OS-Ubuntu/apt`). Installed PCs see it in
**HardPoint Updates** like any other update; installing it re-applies all HardPoint settings.
New apps added to `config/packages.install` are installed by the update too.

- PCs installed from an ISO built after this change are already connected.
- A PC installed before that needs this once, in Terminal:
  `curl -fsSL https://shanes-usernam3.github.io/Hardpoint-OS-Ubuntu/apt/install.sh | sudo sh`
- Updates are signed with the key in the `HP_SIGNING_KEY` Actions secret; PCs trust the public
  half in `overlay/usr/share/keyrings/hardpoint-archive-keyring.gpg`. Without the secret the
  build still works, it just doesn't publish.
- GitHub Pages must serve the `gh-pages` branch (Settings → Pages).

## Layout

| Path | What |
|---|---|
| `build.sh` | Downloads + verifies the base ISO, unpacks, customises, repacks the ISO |
| `config/base.env` | Base ISO name, checksum and mirrors |
| `config/packages.install` | apt packages added (missing ones are skipped and logged) |
| `config/flatpaks.list` | Apps offered in HardPoint Setup |
| `tools/customize.sh` | Runs inside the image: repos, packages, installs hardpoint-os |
| `tools/build-deb.sh`, `tools/publish-apt.sh` | Build the hardpoint-os package and publish the signed update source |
| `overlay/usr/lib/hardpoint/setup/` | What the package runs on install/update: settings, branding, login theme, boot splash |
| `tools/make-branding.py` | Renders logo, wallpapers, boot and login art |
| `overlay/` | Files copied into the system (HardPoint apps, polkit, systemd, Plymouth, hardening) |
| `overlay/usr/lib/hardpoint/ui/` | The HardPoint apps UI (open `index.html` in a browser to preview with sample data) |
| `tools/vm-test.py` | CI VM test |

## Updating the base system

Change `BASE_ISO` and `BASE_SHA256` in `config/base.env` (checksums are on the mirrors in `SHA256SUMS.txt`) and push.
