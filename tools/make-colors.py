#!/usr/bin/env python3
"""Write the HardPoint Dark / Light KDE colour schemes (Byte palette).

    make-colors.py <out-dir>      -> HardPointDark.colors, HardPointLight.colors
"""
import sys
from pathlib import Path

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OUT.mkdir(parents=True, exist_ok=True)

# Byte palette: navy surfaces, neon cyan accent, violet links, pink for warnings
SCHEMES = {
    "HardPointDark": dict(
        name="HardPoint Dark",
        window=(16, 20, 33), window_alt=(24, 28, 46),
        view=(10, 14, 23), view_alt=(18, 22, 36),
        button=(30, 34, 56), button_alt=(12, 47, 53),
        header=(13, 17, 28), header_inactive=(16, 20, 33),
        tooltip=(26, 27, 57),
        complementary=(10, 14, 23),
        fg=(236, 240, 247), fg_inactive=(150, 160, 182),
        accent=(3, 244, 212), accent_dim=(12, 47, 53),
        sel_fg=(10, 14, 23),
        link=(112, 109, 252), visited=(186, 120, 255),
        negative=(255, 46, 150), neutral=(255, 176, 32), positive=(3, 230, 150),
        disabled=(40, 44, 60),
    ),
    "HardPointLight": dict(
        name="HardPoint Light",
        window=(243, 245, 250), window_alt=(232, 235, 243),
        view=(255, 255, 255), view_alt=(246, 247, 251),
        button=(250, 251, 253), button_alt=(214, 248, 243),
        header=(236, 239, 246), header_inactive=(243, 245, 250),
        tooltip=(255, 255, 255),
        complementary=(16, 20, 33),
        fg=(18, 22, 36), fg_inactive=(96, 104, 124),
        accent=(0, 168, 150), accent_dim=(214, 248, 243),
        sel_fg=(255, 255, 255),
        link=(80, 76, 230), visited=(140, 70, 210),
        negative=(220, 20, 110), neutral=(200, 120, 0), positive=(0, 150, 100),
        disabled=(220, 222, 230),
    ),
}


def rgb(c):
    return ",".join(str(v) for v in c)


def group(p, bg, bg_alt, fg=None, fg_inactive=None, active=None):
    fg = fg or p["fg"]
    return "\n".join([
        f"BackgroundAlternate={rgb(bg_alt)}",
        f"BackgroundNormal={rgb(bg)}",
        f"DecorationFocus={rgb(p['accent'])}",
        f"DecorationHover={rgb(p['accent'])}",
        f"ForegroundActive={rgb(active or p['accent'])}",
        f"ForegroundInactive={rgb(fg_inactive or p['fg_inactive'])}",
        f"ForegroundLink={rgb(p['link'])}",
        f"ForegroundNegative={rgb(p['negative'])}",
        f"ForegroundNeutral={rgb(p['neutral'])}",
        f"ForegroundNormal={rgb(fg)}",
        f"ForegroundPositive={rgb(p['positive'])}",
        f"ForegroundVisited={rgb(p['visited'])}",
    ])


for key, p in SCHEMES.items():
    dark = key.endswith("Dark")
    comp_fg = (236, 240, 247)
    text = f"""# HardPoint OS colour scheme ({p['name']}) - HardPoint Networks
[ColorEffects:Disabled]
Color={rgb(p['disabled'])}
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
{group(p, p['button'], p['button_alt'])}

[Colors:Complementary]
{group(p, p['complementary'], p['window_alt'] if dark else (30, 34, 56), fg=comp_fg, fg_inactive=(150, 160, 182), active=(3, 244, 212))}

[Colors:Header]
{group(p, p['header'], p['window'])}

[Colors:Header][Inactive]
{group(p, p['header_inactive'], p['header'])}

[Colors:Selection]
{group(p, p['accent'], p['accent_dim'], fg=p['sel_fg'], fg_inactive=p['sel_fg'], active=p['sel_fg'])}

[Colors:Tooltip]
{group(p, p['tooltip'], p['window'])}

[Colors:View]
{group(p, p['view'], p['view_alt'])}

[Colors:Window]
{group(p, p['window'], p['window_alt'])}

[General]
ColorScheme={key}
Name={p['name']}
shadeSortColumn=true
AccentColor={rgb(p['accent'])}

[KDE]
contrast=4

[WM]
activeBackground={rgb(p['header'])}
activeBlend={rgb(p['fg'])}
activeForeground={rgb(p['fg'])}
inactiveBackground={rgb(p['header_inactive'])}
inactiveBlend={rgb(p['fg_inactive'])}
inactiveForeground={rgb(p['fg_inactive'])}
"""
    (OUT / f"{key}.colors").write_text(text)
    print(OUT / f"{key}.colors")
