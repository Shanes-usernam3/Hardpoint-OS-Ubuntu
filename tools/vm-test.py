#!/usr/bin/env python3
"""HardPoint OS VM test — runs in GitHub Actions after each build.

Phase 1  Live session: boot the ISO, screenshot the desktop, open HardPoint
         Setup and Updates, sign out to show the themed login screen.
Phase 2  Install: Ubiquity images get an automatic preseeded install; Calamares
         images (HardPoint OS 2) are installed by tools/host-install.sh, which does
         the installer's steps directly. Then boot the installed disk: boot splash,
         login screen, sign in and the first-run HardPoint Setup.

Usage: vm-test.py <iso> <results-dir>     (results: PNGs, serial logs, summary.md)
"""
import glob
import http.server
import os
import shutil
import socket
import socketserver
import subprocess
import sys
import textwrap
import threading
import time
from pathlib import Path

from PIL import Image

ISO, OUT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
OUT.mkdir(parents=True, exist_ok=True)
WORK = Path("/tmp/hpvm")
shutil.rmtree(WORK, ignore_errors=True)
WORK.mkdir()
USER, PASS = "hptest", "hardpointtest"
summary = []
KVM = os.access("/dev/kvm", os.W_OK)


def log(m):
    print(f"[{time.strftime('%H:%M:%S')}] {m}", flush=True)


def note(ok, text):
    summary.append(f"- {'✅' if ok else '❌'} {text}")
    log(text)


def find(*pats):
    for p in pats:
        hits = glob.glob(p)
        if hits:
            return hits[0]
    sys.exit(f"missing: {pats}")


CODE = find("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_CODE.fd")
VARS_SRC = find("/usr/share/OVMF/OVMF_VARS_4M.fd", "/usr/share/OVMF/OVMF_VARS.fd")
VARS = WORK / "vars.fd"
shutil.copy(VARS_SRC, VARS)
DISK = WORK / "disk.qcow2"
subprocess.run(["qemu-img", "create", "-q", "-f", "qcow2", str(DISK), "48G"], check=True)
log(f"KVM: {KVM}")

# Kernel + initrd from the ISO so we can pass test options
names = subprocess.run(["bsdtar", "-tf", str(ISO)], capture_output=True, text=True).stdout.split()
kern = next(n for n in names if n.startswith("casper/vmlinuz"))
initrd = next(n for n in names if n.startswith("casper/initrd"))
subprocess.run(["bsdtar", "-xf", str(ISO), "-C", str(WORK), kern, initrd], check=True)
KERNEL, INITRD = WORK / kern, WORK / initrd
manifest = subprocess.run(["bsdtar", "-xOf", str(ISO), "casper/filesystem.manifest"], capture_output=True, text=True).stdout
CALAMARES = any(l.split()[:1] == ["calamares"] for l in manifest.splitlines())
log(f"Installer: {'Calamares' if CALAMARES else 'Ubiquity'}")


class Monitor:
    def __init__(self, path):
        for _ in range(150):
            try:
                self.s = socket.socket(socket.AF_UNIX)
                self.s.connect(str(path))
                break
            except OSError:
                time.sleep(0.2)
        self.s.settimeout(0.5)
        self._drain()

    def _drain(self):
        try:
            while self.s.recv(65536):
                pass
        except OSError:
            pass

    def cmd(self, c):
        try:
            self.s.sendall((c + "\n").encode())
            time.sleep(0.12)
            self._drain()
        except OSError:
            pass


KEYS = {" ": "spc", "-": "minus", ";": "semicolon", "/": "slash", ".": "dot", "=": "equal",
        "_": "shift-minus", "|": "shift-backslash", ",": "comma", "\n": "ret", "@": "shift-2"}


def type_text(mon, text):
    for ch in text:
        k = KEYS.get(ch) or (("shift-" + ch.lower()) if ch.isupper() else ch)
        mon.cmd(f"sendkey {k}")
        time.sleep(0.06)


def shot(mon, name):
    ppm = WORK / f"{name}.ppm"
    mon.cmd(f"screendump {ppm}")
    time.sleep(1.5)
    try:
        Image.open(ppm).save(OUT / f"{name}.png", optimize=True)
        log(f"screenshot {name}")
        return True
    except Exception as e:  # noqa: BLE001
        log(f"screenshot {name} failed: {e}")
        return False


def run_cmd(mon, command):
    """Run dialog (Alt+F2: KRunner on Plasma, the run prompt on GNOME)."""
    mon.cmd("sendkey alt-f2")
    time.sleep(2)
    type_text(mon, command + "\n")


def qemu(extra, serial, mon_sock):
    args = ["qemu-system-x86_64", "-machine", "q35", "-m", "6144", "-smp", "4",
            "-drive", f"if=pflash,format=raw,readonly=on,file={CODE}",
            "-drive", f"if=pflash,format=raw,file={VARS}",
            "-drive", f"file={DISK},if=virtio,format=qcow2",
            "-nic", "user,model=virtio-net-pci", "-vga", "virtio", "-display", "none",
            "-serial", f"file:{serial}", "-monitor", f"unix:{mon_sock},server,nowait", "-no-reboot"]
    if KVM:
        args[1:1] = ["-enable-kvm", "-cpu", "host"]
    return subprocess.Popen(args + extra)


def serial_has(path, text):
    return path.exists() and text in path.read_text(errors="replace")


# ================= Phase 1: live session =================
# ================= Phase 0: boot the ISO like a USB stick written with Rufus DD / dd / Etcher =================
def mean_brightness(png):
    try:
        im = Image.open(png).convert("L").resize((64, 40))
        return sum(im.getdata()) / (64 * 40)
    except Exception:  # noqa: BLE001
        return 0


for mode in ("uefi", "bios"):
    usb = WORK / f"usb-{mode}.img"
    shutil.copyfile(ISO, usb)
    monu = WORK / f"monu-{mode}.sock"
    args = ["qemu-system-x86_64", "-machine", "q35", "-m", "4096", "-smp", "2",
            "-drive", f"if=none,id=stick,format=raw,file={usb}",
            "-device", "qemu-xhci", "-device", "usb-storage,drive=stick,bootindex=0",
            "-vga", "virtio", "-display", "none", "-monitor", f"unix:{monu},server,nowait", "-no-reboot"]
    if mode == "uefi":
        shutil.copyfile(VARS_SRC, WORK / "usb-vars.fd")
        args += ["-drive", f"if=pflash,format=raw,readonly=on,file={CODE}",
                 "-drive", f"if=pflash,format=raw,file={WORK / 'usb-vars.fd'}"]
    if KVM:
        args[1:1] = ["-enable-kvm", "-cpu", "host"]
    vmu = subprocess.Popen(args)
    mu = Monitor(monu)
    time.sleep(12)
    shot(mu, f"00-usb-{mode}-menu")
    time.sleep(140)
    ok = shot(mu, f"00-usb-{mode}-desktop") and mean_brightness(OUT / f"00-usb-{mode}-desktop.png") > 20
    note(ok, f"USB stick boot ({mode.upper()}) reached the live desktop")
    mu.cmd("quit")
    try:
        vmu.wait(timeout=60)
    except subprocess.TimeoutExpired:
        vmu.kill()
    usb.unlink(missing_ok=True)

s1, mon1 = OUT / "serial-live.log", WORK / "mon1.sock"
vm = qemu(["-cdrom", str(ISO), "-kernel", str(KERNEL), "-initrd", str(INITRD),
           "-append", "boot=casper fsck.mode=skip quiet splash console=tty0 console=ttyS0,115200 ---"], s1, mon1)
m = Monitor(mon1)
time.sleep(25)
shot(m, "01-boot-splash")
time.sleep(110)
note(shot(m, "02-live-desktop"), "Live desktop booted")
# Windows 11 layout: Start (Win), quick settings (Win+A), calendar / notifications (Win+N)
for key, name in (("meta_l", "02b-start-menu"), ("meta_l-a", "02c-quick-settings"), ("meta_l-n", "02d-notifications")):
    m.cmd(f"sendkey {key}")
    time.sleep(4)
    shot(m, name)
    m.cmd("sendkey esc")
    time.sleep(2)
run_cmd(m, "hardpoint-app setup")
time.sleep(12)
shot(m, "03-hardpoint-setup")
m.cmd("sendkey ret")              # "Get started"
time.sleep(4)
shot(m, "04-setup-look")
m.cmd("sendkey alt-f4")
time.sleep(3)
run_cmd(m, "hardpoint-app updates")
time.sleep(25)
shot(m, "05-hardpoint-updates")
m.cmd("sendkey alt-f4")
time.sleep(3)
if CALAMARES:
    run_cmd(m, "sudo -E calamares")
    time.sleep(25)
    shot(m, "05b-installer-welcome")
    for i in range(1, 6):
        m.cmd("sendkey alt-n")
        time.sleep(5)
        shot(m, f"05c-installer-page{i}")
    m.cmd("sendkey alt-c")       # Cancel
    time.sleep(2)
    m.cmd("sendkey alt-y")       # confirm
    time.sleep(3)
    run_cmd(m, "qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout")
else:
    run_cmd(m, "gnome-session-quit --logout --no-prompt")
time.sleep(25)
shot(m, "06-login-screen")
m.cmd("quit")
vm.wait(timeout=60)

# ================= Phase 2: install =================
httpd = None
if CALAMARES:
    t0 = time.time()
    r = subprocess.run(["sudo", str(Path(__file__).resolve().parent / "host-install.sh"), str(ISO), str(DISK), USER, PASS],
                       capture_output=True, text=True)
    (OUT / "host-install.log").write_text(r.stdout + r.stderr)
    installed = r.returncode == 0
    note(installed, f"Install onto the test disk {'finished' if installed else 'failed (see host-install.log)'} ({(time.time() - t0) / 60:.0f} min)")
else:
    SEED = textwrap.dedent(f"""
    d-i debian-installer/locale string en_US.UTF-8
    d-i keyboard-configuration/layoutcode string us
    d-i keyboard-configuration/xkb-keymap select us
    d-i time/zone string America/Edmonton
    d-i netcfg/get_hostname string hardpoint-test
    d-i passwd/user-fullname string HardPoint Test
    d-i passwd/username string {USER}
    d-i passwd/user-password password {PASS}
    d-i passwd/user-password-again password {PASS}
    d-i user-setup/allow-password-weak boolean true
    d-i user-setup/encrypt-home boolean false
    d-i partman-auto/disk string /dev/vda
    d-i partman-auto/method string regular
    d-i partman-auto/choose_recipe select atomic
    d-i partman-partitioning/confirm_write_new_label boolean true
    d-i partman/confirm_write_new_label boolean true
    d-i partman/choose_partition select finish
    d-i partman/confirm boolean true
    d-i partman/confirm_nooverwrite boolean true
    d-i partman-efi/non_efi_system boolean true
    ubiquity ubiquity/use_nonfree boolean false
    ubiquity ubiquity/download_updates boolean false
    ubiquity ubiquity/summary note
    ubiquity ubiquity/reboot boolean true
    ubiquity ubiquity/poweroff boolean true
    ubiquity ubiquity/success_command string echo HP-INSTALL-DONE > /dev/ttyS0
    """)
    (WORK / "www").mkdir()
    (WORK / "www" / "hp.seed").write_text(SEED)


    class Quiet(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *a, **k):
            super().__init__(*a, directory=str(WORK / "www"), **k)

        def log_message(self, *a):
            log("seed fetched by VM")



    httpd = socketserver.TCPServer(("0.0.0.0", 8088), Quiet)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()

    s2, mon2 = OUT / "serial-install.log", WORK / "mon2.sock"
    t0 = time.time()
    vm = qemu(["-cdrom", str(ISO), "-kernel", str(KERNEL), "-initrd", str(INITRD),
               "-append", "boot=casper fsck.mode=skip ip=dhcp automatic-ubiquity noprompt url=http://10.0.2.2:8088/hp.seed "
                          "debian-installer/locale=en_US.UTF-8 keyboard-configuration/layoutcode=us "
                          "console=tty0 console=ttyS0,115200 quiet splash ---"], s2, mon2)
    m = Monitor(mon2)
    time.sleep(240)
    shot(m, "07-installer")
    installed = False
    for _ in range(60):  # up to ~60 more minutes
        try:
            vm.wait(timeout=60)
            break
        except subprocess.TimeoutExpired:
            if int(time.time() - t0) % 600 < 60:
                shot(m, f"07b-installer-{int((time.time() - t0) / 60)}min")
    if vm.poll() is None:
        shot(m, "07c-installer-timeout")
        vm.kill()
    installed = serial_has(s2, "HP-INSTALL-DONE") or (DISK.stat().st_size > 3_000_000_000)
    note(installed, f"Automatic install {'finished' if installed else 'did not finish'} ({(time.time() - t0) / 60:.0f} min)")

# ================= Phase 3: installed system =================
if installed:
    s3, mon3 = OUT / "serial-boot.log", WORK / "mon3.sock"
    vm = qemu([], s3, mon3)
    m = Monitor(mon3)
    time.sleep(12)
    shot(m, "08-boot-splash")
    time.sleep(75)
    note(shot(m, "09-login-screen"), "Installed system reached the login screen")
    if not CALAMARES:          # GDM: pick the user first; SDDM: password box is focused
        m.cmd("sendkey ret")
        time.sleep(3)
    type_text(m, PASS + "\n")
    time.sleep(60)
    shot(m, "10-first-run-setup")
    m.cmd("sendkey ret")
    time.sleep(4)
    shot(m, "11-setup-look")
    m.cmd("sendkey alt-f4")
    time.sleep(3)
    for key, name in (("meta_l", "12-start-menu"), ("meta_l-a", "13-quick-settings"), ("meta_l-n", "14-notifications")):
        m.cmd(f"sendkey {key}")
        time.sleep(4)
        shot(m, name)
        m.cmd("sendkey esc")
        time.sleep(2)
    m.cmd("quit")
    try:
        vm.wait(timeout=60)
    except subprocess.TimeoutExpired:
        vm.kill()

if httpd:
    httpd.shutdown()
(OUT / "summary.md").write_text("# HardPoint OS VM test\n\n" + "\n".join(summary) + "\n\n"
                                + "Screenshots: " + ", ".join(sorted(p.name for p in OUT.glob("*.png"))) + "\n")
print((OUT / "summary.md").read_text())
