# HardPoint OS — Zorin Edition

HardPoint OS built on **Zorin OS 18.1 Core** (Ubuntu 24.04 LTS), with HardPoint
branding, a Byte-style setup and login experience, dev/IT/gaming software and
Microsoft Entra ID / Intune support. Built by HardPoint Networks.

Sister project of the Arch-based [HardPoint OS](https://github.com/Shanes-usernam3/Hardpoint-os).

## What you get

| Area | Included |
|---|---|
| Look | Byte design language everywhere: navy glass, neon cyan → violet → pink. HardPoint boot splash, login screen, wallpapers, logos and installer slideshow. Zorin's Windows-style desktop layout. |
| HardPoint apps | **Setup** (runs on first sign-in: look, account type, apps, security), **Updates**, **Accounts**, **Security** — one smooth WebKit UI, admin actions through polkit |
| Accounts | Local account, or **Work or school (Microsoft Entra ID / Azure AD join)** via [Himmelblau](https://himmelblau-idm.org) — sign in at the login screen with your work email, MFA and a PIN. **Intune**: Microsoft's Company Portal app is preinstalled for enrolment. |
| Security | Firewall blocking all incoming, AppArmor, kernel hardening (same set as HardPoint OS), private Wi-Fi MAC addresses, no crash dumps, compressed RAM swap, optional full-disk encryption in the installer, **Lockdown Mode** (USB devices blocked until approved, Bluetooth off, debuggers admin-only, io_uring off) |
| Updates | **HardPoint Updates** checks every 6 hours, notifies you, then shows a checklist of every system / app / firmware update so you choose what installs. Security fixes are flagged. Nothing installs on its own. |
| Dev | VS Code, Git + LFS, build tools, CMake/Ninja, Node.js, Python + pipx, OpenJDK 21, adb/fastboot, Docker + Compose, Podman, QEMU/KVM + virt-manager, ShellCheck. Android Studio in Setup. |
| IT tools | nmap, Wireshark, tcpdump, iperf3, mtr, dig, Remmina (RDP/VNC), FreeRDP, WireGuard/OpenVPN, SMART/NVMe tools, GParted, TestDisk, ddrescue, stress-ng, memtester, fio, hwinfo, inxi. RustDesk in Setup. |
| Gaming | Steam, GameMode, MangoHud, Vulkan (32 + 64-bit), **Xbox Cloud Gaming** launcher (Edge) — plus Greenlight, RetroArch, Dolphin, PCSX2, PPSSPP, mGBA, melonDS, Cemu, DuckStation, Heroic offered in Setup |
| Browser | Microsoft Edge (needed for Intune sign-in and Xbox Cloud Gaming) and Zorin's Firefox |

## Licensing

Only the **free Zorin OS Core** edition is used — Zorin OS Pro may not be redistributed.
Zorin's [trademark policy](https://zorin.com/legal/trademark-copyright-and-licensing-policy/) says a derivative
must not use their name or logos or suggest affiliation, so `tools/rebrand.sh` replaces the OS
name, launcher names, logos, boot splash, login theme and installer slideshow. Replaced files are
kept next to ours as `*.zorin` (via `dpkg-divert`), so Zorin updates never bring their branding back.
Package names and some internal file names still contain "zorin"; that is normal for a derivative.
HardPoint OS is not affiliated with or endorsed by Zorin Group.

## 1. Build the ISO (no commands needed)

Every push to `main` builds a new ISO with GitHub Actions (about 60–90 minutes).

1. Open **Actions → Build HardPoint OS (Zorin Edition) ISO** (or click **Run workflow**).
2. When the run is green, download **hardpoint-os-zorin-iso** (a zip with the `.iso` and `SHA256SUMS`).
3. The **Test in a VM** job then boots the ISO, opens the HardPoint apps, does an automatic
   install and boots it. Screenshots and `summary.md` go to the `test-results` branch.

Local build (Ubuntu 24.04, ~40 GB free): `sudo ./build.sh` → `out/`.
Without Himmelblau packages in `extra-pkgs/` the ISO still builds, just without work/school sign-in.

## 2. Make the USB with Rufus

1. Pick the USB stick and the `hardpoint-os-zorin-*.iso`.
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
- Microsoft officially supports Intune on Ubuntu. HardPoint OS is Ubuntu 24.04 underneath, but it
  identifies itself as HardPoint OS, so a compliance policy that only *allows* the "Ubuntu"
  distribution will mark it non-compliant. Leave the allowed-distribution setting empty for these devices.
- Conditional Access rules that require MFA work. Rules that require a compliant device work once the PC is enrolled and compliant.
- The Himmelblau version is pinned in `.github/workflows/build-iso.yml` (`HIMMELBLAU_TAG`).

## Layout

| Path | What |
|---|---|
| `build.sh` | Downloads + verifies Zorin Core, unpacks, customises, repacks the ISO |
| `config/base.env` | Base ISO name, checksum and mirrors |
| `config/packages.install` | apt packages added (missing ones are skipped and logged) |
| `config/flatpaks.list` | Apps offered in HardPoint Setup |
| `tools/customize.sh` | Runs inside the image: repos, packages, settings, security |
| `tools/rebrand.sh`, `tools/apply-logos.py` | Name/logo replacement |
| `tools/gdm-theme.sh` | Byte-style login screen |
| `tools/make-branding.py` | Renders logo, wallpapers, boot and login art |
| `overlay/` | Files copied into the system (HardPoint apps, polkit, systemd, Plymouth, hardening) |
| `overlay/usr/lib/hardpoint/ui/` | The HardPoint apps UI (open `index.html` in a browser to preview with sample data) |
| `tools/vm-test.py` | CI VM test |

## Updating to a newer Zorin release

Change `ZORIN_ISO` and `ZORIN_SHA256` in `config/base.env` (checksums are on Zorin's mirrors in `SHA256SUMS.txt`) and push.
