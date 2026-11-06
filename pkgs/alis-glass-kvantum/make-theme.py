#!/usr/bin/env python3
"""Make the ALIS Glass Kvantum theme from Kvantum's own KvFlat (by Tsu Jan, GPL-3.0).

  make-theme.py <KvFlat dir> <output dir>

Every colour is moved onto the ALIS Glass palette (alis-core/alis_glass_theme.css):
  greys  -> ALIS dark greens / mint whites at the same brightness
  blues  -> ALIS teal at the same brightness
then frosted-glass translucency is switched on.
"""
import colorsys
import os
import re
import sys

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)


def recolour(hexcol):
    r, g, b = (int(hexcol[i:i + 2], 16) / 255 for i in (1, 3, 5))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    deg = h * 360
    if s < 0.12:                        # grey
        if l > 0.7:                     # light greys -> mint white
            h2, l2, s2 = 155 / 360, min(0.95, l), 0.35
        else:                           # dark greys -> ALIS dark green
            h2, l2, s2 = 162 / 360, l * 0.62, 0.42
    elif 180 <= deg <= 235:             # Breeze blues -> ALIS teal
        h2, l2, s2 = 172 / 360, min(0.62, l * 0.95 + 0.04), min(0.75, s)
    else:
        return hexcol
    r, g, b = colorsys.hls_to_rgb(h2, l2, s2)
    return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))


def fix(text):
    return re.sub(r"#[0-9a-fA-F]{6}\b", lambda m: recolour(m.group(0)), text)


svg = fix(open(os.path.join(src, "KvFlat.svg")).read())
open(os.path.join(out, "ALISGlass.svg"), "w").write(svg)

cfg = fix(open(os.path.join(src, "KvFlat.kvconfig")).read())
cfg = cfg.replace("text.focus.color=#7DDCFF", "text.focus.color=#5EEAD4")
cfg = re.sub(r"^author=.*$", "author=Tsu Jan (KvFlat); ALIS Glass colours by ALIS OS", cfg, count=1, flags=re.M)
cfg = re.sub(r"^comment=.*$", "comment=ALIS Glass: frosted dark teal, made from KvFlat", cfg, count=1, flags=re.M)
# Frosted glass: windows and menus slightly see-through, blurred behind (needs KWin blur).
cfg = cfg.replace("composite=true", "\n".join([
    "composite=true", "translucent_windows=true", "blurring=true", "popup_blurring=true",
    "reduce_window_opacity=12", "reduce_menu_opacity=8", "menu_blur_radius=12", "tooltip_blur_radius=8"]), 1)
colours = """[GeneralColors]
window.color=#0C1C18
base.color=#08150F
alt.base.color=#0E201B
button.color=#14302A
light.color=#1E3F37
mid.light.color=#173029
dark.color=#05100D
mid.color=#12271F
shadow.color=#000000
highlight.color=#1FB5A3
inactive.highlight.color=#7C6BD6
text.color=#E8F5F0
window.text.color=#E8F5F0
button.text.color=#E8F5F0
disabled.text.color=#8A9A96
tooltip.text.color=#E8F5F0
highlight.text.color=#05100D
link.color=#2DD4BF
link.visited.color=#A78BFA
progress.indicator.text.color=#05100D
"""
cfg = re.sub(r"\[GeneralColors\]\n(?:[^\[]*\n)", colours + "\n", cfg, count=1)
open(os.path.join(out, "ALISGlass.kvconfig"), "w").write(cfg)
