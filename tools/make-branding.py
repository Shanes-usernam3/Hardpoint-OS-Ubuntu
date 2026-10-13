#!/usr/bin/env python3
"""Render all HardPoint OS raster branding in the Byte style.

    make-branding.py <out-dir>

Needs Pillow, numpy and rsvg-convert (librsvg2-bin); the logo comes from branding/hardpoint-logo.svg. Produces logo PNGs, wallpapers, login and boot art.
Byte palette: navy #0A0E17 / #1A1B39 / #0C2F35, neon cyan #03F4D4 -> violet #706DFC -> pink #FF2E96.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "out-branding")
OUT.mkdir(parents=True, exist_ok=True)

CYAN, VIOLET, PINK = (3, 244, 212), (112, 109, 252), (255, 46, 150)
NAVY0, NAVY1, TEAL = (10, 14, 23), (26, 27, 57), (12, 47, 53)

FONT_DIRS = ["/usr/share/fonts/opentype/inter", "/usr/share/fonts/truetype/inter",
             "/usr/share/fonts/truetype/ubuntu", "/usr/share/fonts/truetype/dejavu"]


def font(bold, size):
    names = (["Inter-Bold.otf", "Inter-Bold.ttf", "Ubuntu-B.ttf", "DejaVuSans-Bold.ttf"] if bold else
             ["Inter-Regular.otf", "Inter-Regular.ttf", "Ubuntu-R.ttf", "DejaVuSans.ttf"])
    for d in FONT_DIRS:
        for n in names:
            p = Path(d) / n
            if p.exists():
                return ImageFont.truetype(str(p), size)
    return ImageFont.load_default(size)


def gradient(w, h, stops=(CYAN, VIOLET, PINK), angle=45):
    """Linear multi-stop gradient as an RGB numpy array."""
    a = math.radians(angle)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = (xx * math.cos(a) + yy * math.sin(a))
    t = (t - t.min()) / max(1e-6, t.max() - t.min())
    n = len(stops) - 1
    out = np.zeros((h, w, 3), np.float32)
    for i in range(n):
        lo, hi = i / n, (i + 1) / n
        m = (t >= lo) & (t <= hi)
        k = ((t - lo) / (hi - lo))[m][:, None]
        out[m] = np.array(stops[i]) * (1 - k) + np.array(stops[i + 1]) * k
    return out


LOGO_SVG = Path(__file__).resolve().parent.parent / "branding" / "hardpoint-logo.svg"
BLUE, BLUE_LT, BLUE_DK = (42, 168, 242), (127, 211, 255), (22, 103, 224)
_logo_cache = {}


def _render_svg(svg, px):
    """Rasterise an SVG with rsvg-convert (librsvg2-bin)."""
    import io, subprocess
    png = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), str(svg)],
                         check=True, capture_output=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


def logo(size, glow=False):
    """HardPoint Networks hexagon-H mark as RGBA size x size (optional soft blue glow)."""
    if size not in _logo_cache:
        big = _render_svg(LOGO_SVG, max(size * 4, 512))
        _logo_cache[size] = big.resize((size, size), Image.LANCZOS)
    out = _logo_cache[size].copy()
    if glow:
        pad = size // 6
        S = size + 2 * pad
        g = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        tint = Image.new("RGBA", (size, size), BLUE + (170,))
        g.paste(tint, (pad, pad), out.split()[3])
        g = g.filter(ImageFilter.GaussianBlur(size / 12))
        g.alpha_composite(out, (pad, pad))
        out = g.resize((size, size), Image.LANCZOS)
    return out


def font_file(names, size):
    for d in FONT_DIRS:
        for n in names:
            p = Path(d) / n
            if p.exists():
                return ImageFont.truetype(str(p), size)
    return font(True, size)


def backdrop(w, h, dim=1.0):
    """Byte-style navy background with soft neon aurora glows."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = xx / w, yy / h
    base = (np.array(TEAL) * (1 - v[..., None]) * 0.9 + np.array(NAVY1) * 0.55
            + np.array(NAVY0) * v[..., None]) / 1.45
    img = base.copy()

    def blob(cx, cy, rx, ry, col, strength):
        d = ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2
        return np.exp(-d)[..., None] * np.array(col) * strength

    # flowing ribbon of light (sine band) plus three glows
    band = np.exp(-((v - (0.62 + 0.08 * np.sin(u * 5.2 + 0.6))) / 0.05) ** 2)[..., None]
    band_col = gradient(w, h, angle=0)
    img += band * band_col * 0.22
    band2 = np.exp(-((v - (0.70 + 0.06 * np.sin(u * 4.1 + 2.1))) / 0.025) ** 2)[..., None]
    img += band2 * band_col * 0.18
    img += blob(0.18, 0.30, 0.35, 0.45, CYAN, 0.16)
    img += blob(0.55, 0.75, 0.45, 0.35, VIOLET, 0.20)
    img += blob(0.90, 0.25, 0.30, 0.40, PINK, 0.14)
    # faint dot grid (very subtle "byte" texture)
    step = max(24, w // 80)
    dots = ((xx % step < 2) & (yy % step < 2)).astype(np.float32)[..., None]
    img += dots * 10
    # vignette
    vig = 1 - 0.45 * (((u - 0.5) * 1.6) ** 2 + ((v - 0.5) * 1.6) ** 2)
    img *= vig[..., None].clip(0.35, 1) * dim
    rng = np.random.default_rng(7)
    img += rng.normal(0, 1.4, img.shape)  # dither: no banding
    return Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGB")


def wordmark(height, sub="OS", dark_bg=True, mark=True):
    """Logo + "HardPoint" ("Point" in brand blue, bold italic) with a spaced sub-line
    such as "— OS —" or "— NETWORKS —", like the HardPoint Networks wordmark."""
    f1 = font_file(["Inter-ExtraBoldItalic.otf", "InterDisplay-ExtraBoldItalic.otf",
                    "Inter-BoldItalic.otf"], height)
    f2 = font_file(["Inter-SemiBold.otf", "Inter-Medium.otf"], int(height * 0.30))
    hard_col = (242, 244, 255, 255) if dark_bg else (44, 50, 64, 255)
    sub_col = (176, 188, 214, 255) if dark_bg else (60, 66, 80, 255)
    tmp = ImageDraw.Draw(Image.new("L", (1, 1)))
    wh, wp = tmp.textlength("Hard", font=f1), tmp.textlength("Point", font=f1)
    w1 = int(wh + wp + height * 0.12)
    track = height * 0.16
    w2 = int(sum(tmp.textlength(c, font=f2) + track for c in sub)) if sub else 0
    lg = int(height * 1.6) if mark else 0
    gap = int(height * 0.32) if mark else 0
    H = int(height * (1.75 if sub else 1.3)) if not mark else max(lg, int(height * 1.75))
    W = lg + gap + max(w1, w2 + int(height * 1.2)) + 4
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if mark:
        img.alpha_composite(logo(lg), (0, (H - lg) // 2))
    x = lg + gap
    ty = int((H - height * (1.62 if sub else 1.0)) / 2) - int(height * 0.12)
    d = ImageDraw.Draw(img)
    d.text((x, ty), "Hard", font=f1, fill=hard_col)
    # "Point" with the brand blue gradient
    pm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(pm).text((x + wh, ty), "Point", font=f1, fill=255)
    gx = np.linspace(0, 1, W)[None, :, None]
    lo, hi = np.array(BLUE_DK, np.float32), np.array(BLUE if dark_bg else BLUE_DK, np.float32)
    top = np.array(BLUE_LT if dark_bg else BLUE, np.float32)
    yy = np.linspace(0, 1, H)[:, None, None]
    col = (top * (1 - yy) + lo * yy) * 0.6 + hi * 0.4 + gx * 0
    rgba = np.concatenate([np.broadcast_to(col, (H, W, 3)), np.array(pm, np.float32)[..., None]], axis=2)
    img.alpha_composite(Image.fromarray(rgba.clip(0, 255).astype(np.uint8), "RGBA"))
    if sub:
        sw = w2 - track
        cx_center = x + w1 / 2
        sy = ty + int(height * 1.22)
        sx = cx_center - sw / 2
        line_y = sy + int(height * 0.17)
        lw = max(1, height // 28)
        d.line((x + 2, line_y, sx - height * 0.25, line_y), fill=sub_col[:3] + (150,), width=lw)
        d.line((sx + sw + height * 0.25, line_y, x + w1, line_y), fill=sub_col[:3] + (150,), width=lw)
        cx = sx
        for ch in sub:
            d.text((cx, sy), ch, font=f2, fill=sub_col)
            cx += tmp.textlength(ch, font=f2) + track
    return img.crop(img.getbbox())


def main():
    for s in (16, 22, 24, 32, 48, 64, 96, 128, 256, 512):
        logo(s).save(OUT / f"logo-{s}.png")
    logo(256, glow=True).save(OUT / "logo-glow-256.png")

    wp = backdrop(3840, 2160)
    wp.save(OUT / "wallpaper-dark.png", optimize=True)
    light = backdrop(1920, 1080)
    light = Image.blend(light, Image.new("RGB", light.size, (232, 236, 250)), 0.72)
    light.resize((3840, 2160), Image.LANCZOS).save(OUT / "wallpaper-light.png", optimize=True)

    login = backdrop(1920, 1080, dim=0.78).filter(ImageFilter.GaussianBlur(6))
    login.save(OUT / "login.png", optimize=True)

    grub = backdrop(1920, 1080, dim=0.6)
    gl = logo(160, glow=True)
    grub.paste(gl, (880, 300), gl)
    grub.save(OUT / "grub.png")

    wordmark(64).save(OUT / "wordmark.png")
    wordmark(40, sub=None).save(OUT / "login-logo.png")
    # HardPoint Networks company wordmarks (dark and light backgrounds)
    wordmark(96, sub="NETWORKS").save(OUT / "networks-wordmark-dark.png")
    wordmark(96, sub="NETWORKS", dark_bg=False).save(OUT / "networks-wordmark-light.png")

    # Plymouth parts
    logo(180, glow=True).save(OUT / "plymouth-logo.png")
    dot = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ImageDraw.Draw(dot).ellipse((8, 8, 56, 56), fill=(255, 255, 255, 255))
    dot = dot.filter(ImageFilter.GaussianBlur(1.2)).resize((16, 16), Image.LANCZOS)
    dot.save(OUT / "plymouth-dot.png")
    bar = Image.fromarray(gradient(320, 4, angle=0).astype(np.uint8), "RGB").convert("RGBA")
    bar.save(OUT / "plymouth-bar.png")
    track = Image.new("RGBA", (320, 4), (255, 255, 255, 40))
    track.save(OUT / "plymouth-track.png")
    print("branding written to", OUT)


if __name__ == "__main__":
    main()
