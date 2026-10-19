#!/usr/bin/env python3
"""Build the HardPoint desktop themes from the base system's (GPL-2) themes, recoloured to Byte.

    make-theme.py <base-theme-dir> <out-dir> dark|light

HardPoint-Dark  (from the dark blue base theme):  navy glass, Byte cyan highlights, soft white text,
                                       pink for errors.
HardPoint-Light (from the light blue base theme): clean light greys, Byte violet highlights, navy text.

Every colour in the CSS / SVG / gtkrc / XPM files and every PNG asset is remapped,
so the GTK apps, the menu, panel, pop-ups and the login/lock UI all match.
"""
import colorsys
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # PNG assets are then left as they are
    Image = None

SRC, DST, MODE = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]
NAME = "HardPoint-Dark" if MODE == "dark" else "HardPoint-Light"
OLD = SRC.name

# Exact replacements for the key accent colours (by role); everything else is mapped by rule
if MODE == "dark":
    EXACT_BG = {"bde6fb": (0x45, 0xE6, 0xD3)}   # selections, switches, focus, buttons: Byte cyan
    EXACT_FG = {"bde6fb": (0xE9, 0xEB, 0xFB)}   # text: soft white with a violet tint
else:
    EXACT_BG = {"15a6f0": (0x6B, 0x68, 0xF5), "22c5fd": (0x8A, 0x87, 0xFF), "029be9": (0x5A, 0x57, 0xEE)}
    EXACT_FG = {"15a6f0": (0x5A, 0x57, 0xEE), "123354": (0x1A, 0x1B, 0x39)}


def hls(rgb):
    return colorsys.rgb_to_hls(*(c / 255 for c in rgb))


def rgb(h, l, s):
    return tuple(max(0, min(255, round(c * 255))) for c in colorsys.hls_to_rgb(h % 1, max(0, min(1, l)), max(0, min(1, s))))


def remap(c, fg=False):
    """Map one base-theme colour (r,g,b) to its HardPoint colour."""
    key = "%02x%02x%02x" % c
    table = EXACT_FG if fg else EXACT_BG
    if key in table:
        return table[key]
    if key in EXACT_BG and fg is False:
        return EXACT_BG[key]
    h, l, s = hls(c)
    deg = h * 360
    if s < 0.04:                       # pure greys, black, white: unchanged
        return c
    if deg < 15 or deg > 345:          # reds -> Byte pink
        return rgb(335 / 360, l, s)
    if 135 <= deg < 180 and s > 0.4:   # base green (checkboxes, success) -> Byte cyan / violet
        return rgb(172 / 360, l, s) if MODE == "dark" else rgb(242 / 360, min(0.68, l), min(1, s))
    if not 180 <= deg <= 222:          # oranges, yellows: unchanged
        return c
    if MODE == "dark":
        if l > 0.55 and s > 0.45:      # base pale blue accent family
            return rgb(235 / 360, l, 0.6) if fg else rgb(172 / 360, l, min(1, s * 0.95))
        if l < 0.35:                   # blue-grey backgrounds -> navy
            return rgb(233 / 360, l * 0.92, min(0.45, 0.12 + s * 1.5))
        return rgb(233 / 360, l, min(0.3, s * 1.1 + 0.04))  # grey text / borders
    # light
    if s > 0.5 and 0.3 < l < 0.75:     # blue accent family -> violet
        return rgb(242 / 360, min(0.72, l + 0.08), min(1, s))
    if l < 0.35:                       # dark blue text -> navy
        return rgb(238 / 360, l, s * 0.6)
    return rgb(235 / 360, l, s)        # light blue-grey surfaces


HEX = re.compile(r"#([0-9a-fA-F]{6})\b|#([0-9a-fA-F]{3})\b(?![0-9a-fA-F])")
RGBA = re.compile(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,\s*[\d.]+\s*)?\)")


def sub_colors(text, fg=False):
    def hx(m):
        if m.group(1):
            v = m.group(1)
            c = tuple(int(v[i:i + 2], 16) for i in (0, 2, 4))
        else:
            v = m.group(2)
            c = tuple(int(ch * 2, 16) for ch in v)
        n = remap(c, fg)
        out = "#%02x%02x%02x" % n
        return out if m.group(1) or n != c else m.group(0)

    def rg(m):
        c = tuple(int(m.group(i)) for i in (1, 2, 3))
        n = remap(c, fg)
        a = m.group(4) or ""
        return f"rgba({n[0]}, {n[1]}, {n[2]}{a})" if a else f"rgb({n[0]}, {n[1]}, {n[2]})"

    return RGBA.sub(rg, HEX.sub(hx, text))


DECL = re.compile(r"(?<![\w-])([\w-]+)(\s*:\s*)([^;{}]+)")
FG_PROPS = {"color", "-gtk-icon-palette", "caret-color", "-gtk-secondary-caret-color"}


def recolor_css(text):
    def decl(m):
        prop = m.group(1).lower()
        return m.group(1) + m.group(2) + sub_colors(m.group(3), fg=prop in FG_PROPS)
    # @define-color name value;
    text = re.sub(r"(@define-color\s+[\w-]+\s+)([^;]+)",
                  lambda m: m.group(1) + sub_colors(m.group(2), fg="fg" in m.group(1) or "text" in m.group(1)), text)
    return DECL.sub(decl, text)


def recolor_png(p):
    if Image is None:
        return
    im = Image.open(p).convert("RGBA")
    px = im.load()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            k = (r, g, b)
            if k not in cache:
                cache[k] = remap(k)
            px[x, y] = cache[k] + (a,)
    im.save(p)


def recolor_file(p):
    suf = p.suffix.lower()
    if suf == ".png":
        recolor_png(p)
    elif suf == ".css":
        p.write_text(recolor_css(p.read_text(errors="replace")))
    elif suf in (".svg", ".xpm") or p.name in ("gtkrc", "themerc") or suf == ".rc":
        p.write_text(sub_colors(p.read_text(errors="replace")))


def rebuild_gresource(gr):
    """Unpack, recolour and repack a .gresource bundle (the login / lock screen uses it)."""
    try:
        paths = subprocess.run(["gresource", "list", str(gr)], capture_output=True, text=True, check=True).stdout.split()
    except (OSError, subprocess.CalledProcessError):
        return
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        for rp in paths:
            f = root / rp.lstrip("/")
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_bytes(subprocess.run(["gresource", "extract", str(gr), rp], capture_output=True, check=True).stdout)
            recolor_file(f)
        xml = ['<?xml version="1.0" encoding="UTF-8"?>', "<gresources>", '  <gresource prefix="/">']
        xml += [f"    <file>{rp.lstrip('/')}</file>" for rp in paths]
        xml += ["  </gresource>", "</gresources>"]
        (root / "res.xml").write_text("\n".join(xml))
        subprocess.run(["glib-compile-resources", f"--sourcedir={root}", f"--target={gr}", str(root / "res.xml")], check=True)


def main():
    if DST.exists():
        shutil.rmtree(DST)
    shutil.copytree(SRC, DST, symlinks=True)
    for p in DST.rglob("*"):
        if p.is_file() and not p.is_symlink():
            try:
                if p.suffix == ".gresource":
                    rebuild_gresource(p)
                else:
                    recolor_file(p)
            except Exception as e:  # one odd asset must not stop the theme
                print(f"  skip {p.relative_to(DST)}: {e}")
    idx = DST / "index.theme"
    if idx.exists():
        t = idx.read_text()
        t = re.sub(r"^Name=.*$", f"Name={NAME}", t, flags=re.M)
        t = re.sub(r"^Comment=.*$", f"Comment=HardPoint OS {MODE} theme (Byte style)", t, flags=re.M)
        t = t.replace(f"GtkTheme={OLD}", f"GtkTheme={NAME}").replace(f"MetacityTheme={OLD}", f"MetacityTheme={NAME}")
        t = re.sub(r"^IconTheme=.*$", "IconTheme=" + ("Papirus-Dark" if MODE == "dark" else "Papirus"), t, flags=re.M)
        idx.write_text(t)
    for f in DST.rglob("*"):  # any text that names the source theme
        if f.is_file() and f.suffix in (".css", ".rc", ".theme") or f.name in ("gtkrc", "themerc"):
            try:
                s = f.read_text()
                if OLD in s:
                    f.write_text(s.replace(OLD, NAME))
            except (UnicodeDecodeError, OSError):
                pass
    # Windows 11 shapes for the menu, panel pop-ups, quick settings and notifications
    extra = Path(__file__).with_name("shell-win11.css")
    shell_css = DST / "gnome-shell" / "gnome-shell.css"
    if extra.exists() and shell_css.exists():
        with shell_css.open("a") as fh:
            fh.write("\n" + extra.read_text())
    print(f"  -> {NAME} built from {OLD}")


if __name__ == "__main__":
    main()
