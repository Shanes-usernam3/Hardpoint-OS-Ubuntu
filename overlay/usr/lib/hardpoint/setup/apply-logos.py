#!/usr/bin/env python3
"""Overwrite each Zorin logo image listed by rebrand.sh with the HardPoint logo,
rendered at the same pixel size (PNG) or as SVG.

    apply-logos.py <root> <targets.txt> <branding-dir>
"""
import sys
from pathlib import Path

from PIL import Image

ROOT, LIST, BR = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
LOGO_SVG = (BR / "hardpoint-logo.svg").read_text()
SYMBOLIC_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
  <path fill="#2e3436" fill-rule="evenodd" d="M8 .4 14.6 4.2V11.8L8 15.6 1.4 11.8V4.2Z
     M4.6 4.8v6.9l2.1-.3V9h2.6v2.1l2.1-.3V4.1l-2.1.3v2.4H6.7V4.5Z"/>
</svg>
"""
big_logo = Image.open(BR / "logo-512.png").convert("RGBA")
CONNECT_SVG = (BR / "hardpoint-connect.svg").read_text() if (BR / "hardpoint-connect.svg").exists() else LOGO_SVG
CONNECT_SYM = (BR / "hardpoint-connect-symbolic.svg").read_text() if (BR / "hardpoint-connect-symbolic.svg").exists() else SYMBOLIC_SVG
CONNECT_PNG = BR / "connect-512.png"
connect_img = Image.open(CONNECT_PNG).convert("RGBA") if CONNECT_PNG.exists() else big_logo
APPEAR_SVG = (BR / "hardpoint-appearance.svg").read_text() if (BR / "hardpoint-appearance.svg").exists() else LOGO_SVG
APPEAR_SYM = (BR / "hardpoint-appearance-symbolic.svg").read_text() if (BR / "hardpoint-appearance-symbolic.svg").exists() else SYMBOLIC_SVG
APPEAR_PNG = BR / "appearance-512.png"
appear_img = Image.open(APPEAR_PNG).convert("RGBA") if APPEAR_PNG.exists() else big_logo
wordmark = Image.open(BR / "wordmark.png").convert("RGBA")


def fit(src, w, h, pad=0.06):
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bw, bh = int(w * (1 - 2 * pad)), int(h * (1 - 2 * pad))
    s = min(bw / src.width, bh / src.height)
    im = src.resize((max(1, int(src.width * s)), max(1, int(src.height * s))), Image.LANCZOS)
    canvas.alpha_composite(im, ((w - im.width) // 2, (h - im.height) // 2))
    return canvas


done = 0
for line in LIST.read_text().splitlines():
    if not line.strip():
        continue
    p = ROOT / line.lstrip("/")
    try:
        low = p.name.lower()
        kind = "connect" if "connect" in low else ("appearance" if "appearance" in low else "logo")
        if p.suffix.lower() == ".svg":
            sym = "symbolic" in low
            svg = {"connect": (CONNECT_SYM, CONNECT_SVG), "appearance": (APPEAR_SYM, APPEAR_SVG),
                   "logo": (SYMBOLIC_SVG, LOGO_SVG)}[kind]
            p.write_text(svg[0] if sym else svg[1])
        elif kind != "logo":
            with Image.open(p) as old:
                w, h = old.size
            fit(connect_img if kind == "connect" else appear_img, w, h, pad=0.0).save(p)
        else:
            with Image.open(p) as old:
                w, h = old.size
            src = wordmark if w / max(h, 1) > 1.6 else big_logo
            fit(src, w, h, pad=0.02 if src is big_logo else 0.06).save(p)
        done += 1
    except Exception as e:  # keep going; one odd file shouldn't fail the build
        print(f"  skip {line}: {e}")
print(f"  -> replaced {done} logo images")
