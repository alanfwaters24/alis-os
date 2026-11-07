#!/usr/bin/env python3
"""LibreOffice "ALIS" toolbar icons: LibreOffice's own Breeze Dark SVG set
(the one it picks under KDE) with every colour moved onto ALIS duotone, using
the same rules as the ALIS system icons (pkgs/alis-icons/recolour.py).

  make.py <images_breeze_dark_svg.zip> <recolour.py dir> <out images_alis_svg.zip>
"""
import sys
import zipfile

src, rules, out = sys.argv[1:4]
sys.path.insert(0, rules)
from recolour import cache, recolour_svg  # noqa: E402

n = 0
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename.endswith(".svg"):
            new = recolour_svg(data.decode("utf-8", "surrogateescape")).encode("utf-8", "surrogateescape")
            n += new != data
            data = new
        zout.writestr(item, data)
print(f"ALIS LibreOffice icons: recoloured {n} icons, {len(cache)} distinct colours")
