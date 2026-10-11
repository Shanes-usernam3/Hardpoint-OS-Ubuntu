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
  <path fill="#2e3436" d="M8 .9 13.9 3v4.6c0 3.8-2.5 6.3-5.9 7.5C4.6 13.9 2.1 11.4 2.1 7.6V3Z
     M5.5 4.5v7h1.4V8.6h2.2v2.9h1.4v-7H9.1v2.7H6.9V4.5Z" fill-rule="evenodd"/>
</svg>
"""
big_logo = Image.open(BR / "logo-512.png").convert("RGBA")
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
        if p.suffix.lower() == ".svg":
            p.write_text(SYMBOLIC_SVG if "symbolic" in p.name else LOGO_SVG)
        else:
            with Image.open(p) as old:
                w, h = old.size
            src = wordmark if w / max(h, 1) > 1.6 else big_logo
            fit(src, w, h, pad=0.02 if src is big_logo else 0.06).save(p)
        done += 1
    except Exception as e:  # keep going; one odd file shouldn't fail the build
        print(f"  skip {line}: {e}")
print(f"  -> replaced {done} logo images")
