#!/usr/bin/env python3
"""OnlyOffice "ALIS" interface theme: OnlyOffice's own Dark theme with every
colour moved onto ALIS (shared rules, pkgs/alis-icons/recolour.py), read
from OnlyOffice's stylesheet so it follows OnlyOffice updates. OnlyOffice's
toolbar icons are built into the app and can't be swapped; they follow the
theme's light/dark type.

  make.py <OnlyOffice documenteditor app.css> <recolour.py dir> <out theme-alis.json>
"""
import colorsys
import json
import re
import sys

css, rules, out = sys.argv[1:4]
sys.path.insert(0, rules)
from recolour import recolour_svg  # noqa: E402

text = open(css, encoding="utf-8").read()
block = None
for m in re.finditer(r"([^{}]*)\{([^}]*)\}", text):
    if ".theme-dark" in m.group(1) and "--toolbar-header-document" in m.group(2):
        block = m.group(2)
        break
if block is None:
    raise SystemExit("OnlyOffice's dark theme wasn't found in its stylesheet")

HEX = re.compile(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")


def ui(m):
    """Dark greys (panel backgrounds) -> the deep ALIS Glass greens of the
    desktop's own panels; everything else by the shared ALIS rules."""
    h = m.group(0).lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, light, sat = colorsys.rgb_to_hls(r, g, b)
    if sat < 0.10 and light <= 0.6:
        r, g, b = colorsys.hls_to_rgb(162 / 360, light * 0.62, 0.38)
        return "#%02x%02x%02x" % tuple(round(v * 255) for v in (r, g, b))
    return recolour_svg(m.group(0))


colors = {}
for name, value in re.findall(r"--([\w-]+)\s*:\s*([^;]+)", block):
    value = value.strip()
    if value.startswith("var("):          # e.g. var(--background-toolbar): keep the link
        continue
    colors[name] = HEX.sub(ui, value)     # hex colours recoloured; rgba()/sizes left as they are

json.dump({"id": "theme-alis", "name": "ALIS", "type": "dark", "colors": colors}, open(out, "w"), indent=1)
print(f"ALIS OnlyOffice theme: {len(colors)} colours")
