#!/usr/bin/env python3
"""ALIS cursors, made from KDE's Breeze Dark cursors (GPL, KDE VDG): same
shapes, ALIS colours — a dark ALIS-green pointer with a teal edge, teal and
violet for the busy spinner. Writes both kinds KDE uses:
  cursors_scalable/  SVGs (Plasma 6 draws these sharp at any size)
  cursors/           classic Xcursor files (older / X11 apps), rendered here

  make-cursors.py <breeze_cursors dir> <recolour.py dir> <out dir> <rsvg-convert> <xcursorgen>
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

src, rules, out, rsvg, xcursorgen = sys.argv[1:6]
sys.path.insert(0, rules)
from recolour import recolour_svg  # noqa: E402

CURSOR = {           # Breeze Dark colour -> ALIS
    "#333": "#0c1c18", "#333333": "#0c1c18",   # pointer body: ALIS dark green
    "#0d0d0d": "#05100d", "#0c0c0c": "#05100d", "#0a0a0a": "#05100d", "#070707": "#05100d",
    "#fff": "#5eead4", "#ffffff": "#5eead4",   # edge: bright teal
    # Badges keep a contrasting colour, since their white symbols turn teal:
    "#46a7ac": "#05100d",                      # busy spinner: dark arc ...
    "#d4497f": "#a78bfa",                      # ... and violet arc, on a teal ring
    "#3daee9": "#a78bfa",                      # help "?" badge: violet
    "#18c087": "#a78bfa", "#11d116": "#a78bfa",  # copy / link "+" badges: violet
    "#ed1515": "#f87171",                      # not allowed: ALIS warning red
}
colour = re.compile(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")


def paint_all(svg):
    # Known cursor colours first, then any other colour by the shared ALIS rules.
    def one(m):
        k = m.group(0).lower()
        return CURSOR[k] if k in CURSOR else recolour_svg(k)
    svg = colour.sub(one, svg)
    # Shapes with no colour of their own are drawn black: make that ALIS dark green.
    return re.sub(r"<svg\b(?![^>]*\sfill=)", '<svg fill="#0c1c18"', svg, count=1)


SIZES = [24, 30, 36, 48, 60, 72, 96]
scal_src = os.path.join(src, "cursors_scalable")
scal_out = os.path.join(out, "cursors_scalable")
xc_out = os.path.join(out, "cursors")
os.makedirs(scal_out)
os.makedirs(xc_out)

for name in sorted(os.listdir(scal_src)):
    s = os.path.join(scal_src, name)
    if os.path.islink(s):                       # alias, e.g. a hash name -> progress
        os.symlink(os.readlink(s), os.path.join(scal_out, name))
        os.symlink(os.readlink(s), os.path.join(xc_out, name))
        continue
    d = os.path.join(scal_out, name)
    os.makedirs(d)
    for f in os.listdir(s):
        if f.endswith(".svg"):
            open(os.path.join(d, f), "w").write(paint_all(open(os.path.join(s, f)).read()))
        else:
            shutil.copyfile(os.path.join(s, f), os.path.join(d, f))

    # Classic Xcursor: render every frame at every size.
    meta = json.load(open(os.path.join(d, "metadata.json")))
    with tempfile.TemporaryDirectory() as tmp:
        lines = []
        for i, fr in enumerate(meta):
            svgf = os.path.join(d, fr["filename"])
            m = re.search(r'width="([\d.]+)"', open(svgf).read())
            width = float(m.group(1)) if m else 32.0
            nominal = fr.get("nominal_size", 24)
            for size in SIZES:
                k = size / nominal
                px = max(1, round(width * k))
                png = os.path.join(tmp, f"{i}-{size}.png")
                subprocess.run([rsvg, "-w", str(px), "-h", str(px), svgf, "-o", png], check=True)
                line = f"{size} {round(fr['hotspot_x'] * k)} {round(fr['hotspot_y'] * k)} {png}"
                if "delay" in fr:
                    line += f" {fr['delay']}"
                lines.append(line)
        cfg = os.path.join(tmp, "cfg")
        open(cfg, "w").write("\n".join(lines) + "\n")
        subprocess.run([xcursorgen, cfg, os.path.join(xc_out, name)], check=True)

open(os.path.join(out, "index.theme"), "w").write(
    "[Icon Theme]\nName=ALIS\nComment=ALIS cursors (made from Breeze Dark by the KDE VDG)\n")
print("ALIS cursors:", len(os.listdir(scal_out)), "cursors")
