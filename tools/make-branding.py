#!/usr/bin/env python3
"""Render all HardPoint OS raster branding in the Byte style.

    make-branding.py <out-dir>

Needs Pillow and numpy. Produces logo PNGs, wallpapers, login and boot art.
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


def shield_points(s):
    """Shield outline from the SVG (viewBox 256), scaled by s."""
    pts = [(128, 14), (222, 48), (222, 122)]
    # cubic C222 182 182 222 128 242 and C74 222 34 182 34 122
    def bez(p0, p1, p2, p3, n=24):
        return [tuple((1 - t) ** 3 * np.array(p0) + 3 * (1 - t) ** 2 * t * np.array(p1)
                      + 3 * (1 - t) * t ** 2 * np.array(p2) + t ** 3 * np.array(p3))
                for t in np.linspace(0, 1, n)]
    pts += bez((222, 122), (222, 182), (182, 222), (128, 242))
    pts += bez((128, 242), (74, 222), (34, 182), (34, 122))
    pts += [(34, 48)]
    return [(x * s, y * s) for x, y in pts]


H_SHAPE = [(88, 72), (110, 72), (110, 116), (146, 116), (146, 72), (168, 72),
           (168, 184), (146, 184), (146, 138), (110, 138), (110, 184), (88, 184)]


def logo(size, glow=False):
    """RGBA logo of size x size (optionally with a soft neon glow)."""
    ss = 4
    S = size * ss
    k = S / 256
    grad = gradient(S, S)
    stroke = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(stroke)
    pts = shield_points(k)
    d.line(pts + pts[:3], fill=255, width=max(1, int(12 * k)), joint="curve")
    body = Image.new("L", (S, S), 0)
    ImageDraw.Draw(body).polygon(shield_points(k), fill=255)
    hmask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(hmask).polygon([(x * k, y * k) for x, y in H_SHAPE], fill=255)

    fill = np.zeros((S, S, 3), np.float32)
    yy = np.linspace(0, 1, S)[:, None]
    fill[:] = (np.array(NAVY1) * (1 - yy) + np.array(NAVY0) * yy)[:, None, :].reshape(S, 1, 3)
    img = np.zeros((S, S, 4), np.float32)
    b = np.array(body, np.float32)[..., None] / 255
    img[..., :3] = fill * b
    img[..., 3:] = b * 255
    for m in (stroke, hmask):
        a = np.array(m, np.float32)[..., None] / 255
        img[..., :3] = img[..., :3] * (1 - a) + grad * a
        img[..., 3:] = np.maximum(img[..., 3:], a * 255)
    out = Image.fromarray(img.clip(0, 255).astype(np.uint8), "RGBA").resize((size, size), Image.LANCZOS)
    if glow:
        g = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        tint = Image.new("RGBA", (size, size), VIOLET + (150,))
        g.paste(tint, (0, 0), out.split()[3])
        g = g.filter(ImageFilter.GaussianBlur(size / 14))
        g.alpha_composite(out)
        out = g
    return out


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


def wordmark(height, sub=True):
    f1 = font(True, height)
    f2 = font(False, int(height * 0.32))
    t1, t2 = "HardPoint OS", "BY HARDPOINT NETWORKS"
    tmp = ImageDraw.Draw(Image.new("L", (1, 1)))
    w1 = int(tmp.textlength(t1, font=f1)) + 4
    w2 = int(tmp.textlength(t2, font=f2) + len(t2) * height * 0.05)
    lg = int(height * 1.25)
    W = lg + int(height * 0.35) + max(w1, w2)
    H = int(height * (1.75 if sub else 1.3))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    img.alpha_composite(logo(lg), (0, (H - lg) // 2))
    d = ImageDraw.Draw(img)
    x = lg + int(height * 0.35)
    d.text((x, int(height * 0.02)), t1, font=f1, fill=(242, 244, 255, 255))
    if sub:
        cx = x
        for ch in t2:
            d.text((cx, int(height * 1.22)), ch, font=f2, fill=(150, 160, 200, 255))
            cx += tmp.textlength(ch, font=f2) + height * 0.05
    return img


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
    grub.paste(logo(160, glow=True), (880, 300), logo(160, glow=True))
    grub.save(OUT / "grub.png")

    wordmark(64).save(OUT / "wordmark.png")
    wordmark(40, sub=False).save(OUT / "login-logo.png")

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
