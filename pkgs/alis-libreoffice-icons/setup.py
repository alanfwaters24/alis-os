#!/usr/bin/env python3
"""Once per person (at login): tell LibreOffice where the ALIS icon style is
and choose it. LibreOffice keeps settings in registrymodifications.xcu; two
entries are added (any older icon-style entry is replaced). After this the
person can pick another style in Tools → Options → View and it sticks.

  setup.py <folder with images_alis_svg.zip>
"""
import os
import re
import sys

folder = sys.argv[1]
home = os.path.expanduser("~")
marker = os.path.join(home, ".config", "alis-libreoffice-icons-v1")
if os.path.exists(marker):
    raise SystemExit
xcu = os.path.join(home, ".config/libreoffice/4/user/registrymodifications.xcu")

items = (
    '<item oor:path="/org.openoffice.Office.Paths/Paths/org.openoffice.Office.Paths:NamedPath[\'Iconset\']">'
    '<prop oor:name="UserPaths" oor:op="fuse"><value><it>file://' + folder + '</it></value></prop></item>\n'
    '<item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="SymbolStyle" oor:op="fuse">'
    '<value>alis_svg</value></prop></item>\n'
)

if os.path.exists(xcu):
    text = open(xcu, encoding="utf-8").read()
    text = re.sub(r'<item oor:path="/org\.openoffice\.Office\.Common/Misc"><prop oor:name="SymbolStyle".*?</item>\n?', "", text)
    text = re.sub(r'<item oor:path="/org\.openoffice\.Office\.Paths/Paths/org\.openoffice\.Office\.Paths:NamedPath\[\'Iconset\'\]">.*?</item>\n?', "", text)
    if "</oor:items>" not in text:
        raise SystemExit("LibreOffice settings file looks unusual; leaving it alone")
    text = text.replace("</oor:items>", items + "</oor:items>")
else:
    os.makedirs(os.path.dirname(xcu), exist_ok=True)
    text = ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<oor:items xmlns:oor="http://openoffice.org/2001/registry" '
            'xmlns:xs="http://www.w3.org/2001/XMLSchema" '
            'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n' + items + '</oor:items>\n')
tmp = xcu + ".alis-tmp"
open(tmp, "w", encoding="utf-8").write(text)
os.replace(tmp, xcu)
open(marker, "w").close()
