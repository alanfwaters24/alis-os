#!/usr/bin/env python3
"""ALIS Plasma theme (the dock, tray icons, pop-ups and desktop widgets):
Plasma's own Breeze graphics with ALIS colours.
  - colors: the ALIS Glass colour scheme, so everything Plasma tints at run
    time (most tray icons, text, highlights) comes out ALIS
  - every graphic's fixed colours recoloured by the shared ALIS rules
    (pkgs/alis-icons/recolour.py); warning reds stay a clear ALIS red

  make.py <Plasma desktoptheme dir> <recolour.py dir> <ALISGlass.colors> <ALIS wallpaper dir> <out>
"""
import colorsys
import gzip
import json
import os
import re
import shutil
import sys

src_root, rules, colours, wallpaper, out = sys.argv[1:6]
sys.path.insert(0, rules)
from recolour import recolour_svg  # noqa: E402

colour = re.compile(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")


def warning_red(hexcol):
    h = hexcol.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, light, sat = colorsys.rgb_to_hls(r, g, b)
    return sat > 0.4 and (hue * 360 < 15 or hue * 360 > 340)


def paint(svg):
    return colour.sub(lambda m: "#F87171" if warning_red(m.group(0)) else recolour_svg(m.group(0)), svg)


src = os.path.join(src_root, "default")
n = 0
for root, dirs, files in os.walk(src):
    rel = os.path.relpath(root, src)
    os.makedirs(os.path.join(out, rel), exist_ok=True)
    for f in files:
        s, d = os.path.join(root, f), os.path.join(out, rel, f)
        if f.endswith(".svgz"):
            svg = gzip.open(s).read().decode("utf-8", "surrogateescape")
            with gzip.open(d, "wb") as fh:
                fh.write(paint(svg).encode("utf-8", "surrogateescape"))
            n += 1
        elif f.endswith(".svg"):
            open(d, "w").write(paint(open(s).read()))
            n += 1
        elif f not in ("metadata.json", "plasmarc", "colors"):
            shutil.copyfile(s, d)

shutil.copyfile(colours, os.path.join(out, "colors"))
plasmarc = open(os.path.join(src, "plasmarc")).read().replace("defaultWallpaperTheme=Next", "defaultWallpaperTheme=ALIS")
open(os.path.join(out, "plasmarc"), "w").write(plasmarc)
json.dump({
    "KPlugin": {
        "Id": "alis",
        "Name": "ALIS Glass",
        "Description": "ALIS colours on Plasma's Breeze graphics",
        "Authors": [{"Name": "ALIS OS (made from Breeze by the KDE Visual Design Group)"}],
        "License": "LGPL-2.1-or-later",
        "Category": "",
        "Version": "1",
        "Website": "https://github.com/alanfwaters24/alis-os",
    },
    "X-Plasma-API": "5.0",
}, open(os.path.join(out, "metadata.json"), "w"), indent=2)
print(f"ALIS Plasma theme: recoloured {n} graphics")
