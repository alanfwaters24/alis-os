#!/usr/bin/env python3
"""Make the ALIS icon theme from Papirus-Dark (GPL-3.0, Papirus Development Team).

  make-icons.py <icons dir containing Papirus and Papirus-Dark> <output dir>

Every colour in every icon is moved onto ALIS duotone (alis-core palette):
  blues (folders, most accents)   -> ALIS teal
  other colours                   -> spread over teal -> cyan -> violet, so apps
                                     stay tellable apart by shade as well as shape
  light greys / whites            -> ALIS mint-white
  dark greys / blacks             -> ALIS dark green
Shapes are untouched. Symbolic (tray/panel) icons also follow the ALIS colour
scheme's text colour at run time (Papirus' FollowsColorScheme).
"""
import os
import re
import shutil
import sys

src_root, out = sys.argv[1], sys.argv[2]
dark = os.path.join(src_root, "Papirus-Dark")

# 1. Copy Papirus-Dark. Its folders are partly links into Papirus: copy what
#    they point at, but keep links that just point at a neighbour (e.g.
#    "16x16@2x -> 16x16", "categories -> apps") as links, so nothing is
#    stored twice.
def copy_tree(src, dst):
    os.makedirs(dst, exist_ok=True)
    for name in os.listdir(src):
        s, d = os.path.join(src, name), os.path.join(dst, name)
        if os.path.islink(s) and "/" not in os.readlink(s):
            os.symlink(os.readlink(s), d)                 # neighbour link: keep
        elif os.path.isdir(s):
            copy_tree(os.path.realpath(s) if os.path.islink(s) else s, d)
        elif os.path.islink(s) and not os.path.exists(s):
            continue                                       # dangling in Papirus itself
        else:
            shutil.copyfile(os.path.realpath(s), d)


os.makedirs(out)
for name in os.listdir(dark):
    if name == "icon-theme.cache":
        continue
    s, d = os.path.join(dark, name), os.path.join(out, name)
    if os.path.islink(s) and "/" not in os.readlink(s):
        os.symlink(os.readlink(s), d)
    elif os.path.isdir(s):
        copy_tree(os.path.realpath(s) if os.path.islink(s) else s, d)
    else:
        shutil.copyfile(os.path.realpath(s), d)


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recolour import cache, recolour_svg  # noqa: E402


# 2. Recolour every real SVG (links follow automatically).
n = 0
for root, _dirs, files in os.walk(out):
    for f in files:
        p = os.path.join(root, f)
        if not f.endswith(".svg") or os.path.islink(p):
            continue
        with open(p, encoding="utf-8", errors="surrogateescape") as fh:
            svg = fh.read()
        new = recolour_svg(svg)
        if new != svg:
            os.chmod(p, 0o644)
            with open(p, "w", encoding="utf-8", errors="surrogateescape") as fh:
                fh.write(new)
            n += 1

# 3. Name it ALIS.
idx = os.path.join(out, "index.theme")
os.chmod(idx, 0o644)
t = open(idx).read()
t = re.sub(r"^Name=.*$", "Name=ALIS", t, count=1, flags=re.M)
t = re.sub(r"^Comment=.*$", "Comment=ALIS duotone icons (made from Papirus-Dark)", t, count=1, flags=re.M)
open(idx, "w").write(t)
print(f"ALIS icons: recoloured {n} icons, {len(cache)} distinct colours")
