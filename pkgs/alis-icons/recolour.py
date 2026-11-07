"""ALIS duotone colour rules, shared by every ALIS icon pack (system icons,
LibreOffice toolbars, Plasma theme, cursors): one place to tune the look.

  recolour_svg(text) -> text with every #rgb / #rrggbb moved onto ALIS colours
"""
import colorsys
import re


def rgb2hex(r, g, b):
    return "#%02x%02x%02x" % tuple(max(0, min(255, round(v * 255))) for v in (r, g, b))


def alis(hexcol):
    h = hexcol.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, light, sat = colorsys.rgb_to_hls(r, g, b)
    deg = hue * 360
    if sat < 0.10:                               # greys
        if light > 0.6:
            return rgb2hex(*colorsys.hls_to_rgb(155 / 360, min(0.94, light), 0.38))   # mint-white
        return rgb2hex(*colorsys.hls_to_rgb(165 / 360, light * 0.85, 0.30))          # dark green
    if 190 <= deg <= 232:                        # Papirus/Breeze blues -> ALIS teal
        new = 172
    else:                                        # everything else -> teal..cyan..violet
        new = 178 + (deg / 360) * 82             # 178 (teal-cyan) .. 260 (violet)
    sat2 = min(0.85, max(0.45, sat))
    light2 = min(0.82, max(0.22, light))
    return rgb2hex(*colorsys.hls_to_rgb(new / 360, light2, sat2))


colour = re.compile(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")
cache = {}


def fix(m):
    k = m.group(0).lower()
    if k not in cache:
        cache[k] = alis(k)
    return cache[k]


def recolour_svg(svg):
    return colour.sub(fix, svg)
