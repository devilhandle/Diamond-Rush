#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Start from the known-good side-art implementation, then correct the
# touch targets to match the actual visible buttons in the supplied layout.
curl -fsSL "https://raw.githubusercontent.com/devilhandle/Diamond-Rush/2347ff1267ca4dc067dd600f165fb3c2ffb48230/build_side_art.sh" -o .base_build_side_art.sh
bash .base_build_side_art.sh
rm -f .base_build_side_art.sh

python3 - <<'PY'
from pathlib import Path
p = Path('j2me-loader/app/src/main/java/javax/microedition/shell/MicroActivity.java')
s = p.read_text()

# Visible house icon is the UP button.
old = 'if (hit(px, ny, 0.48f, 0.51f, 0.095f, 0.09f)) return Canvas.KEY_SOFT_RIGHT;'
new = 'if (hit(px, ny, 0.48f, 0.51f, 0.115f, 0.105f)) return Canvas.KEY_UP;'
if old in s:
    s = s.replace(old, new, 1)

# The bottom visible arrow is DOWN; do not create another UP target below it.
old2 = '''                if (hit(px, ny, 0.48f, 0.81f, 0.13f, 0.13f)) return Canvas.KEY_DOWN;\n\n                // The visible UP button is lower than the old touch target.\n                // Move the touch center clearly downward onto the arrow itself.\n                if (hit(px, ny, 0.48f, 0.76f, 0.12f, 0.085f)) return Canvas.KEY_UP;'''
new2 = '''                // The bottom visible arrow is DOWN.\n                if (hit(px, ny, 0.48f, 0.81f, 0.13f, 0.13f)) return Canvas.KEY_DOWN;'''
if old2 in s:
    s = s.replace(old2, new2, 1)

old3 = 'if (hit(px, ny, 0.48f, 0.82f, 0.13f, 0.105f)) return Canvas.KEY_UP;\n                if (hit(px, ny, 0.48f, 0.90f, 0.12f, 0.075f)) return Canvas.KEY_DOWN;'
new3 = 'if (hit(px, ny, 0.48f, 0.81f, 0.13f, 0.13f)) return Canvas.KEY_DOWN;'
if old3 in s:
    s = s.replace(old3, new3, 1)

# RIGHT PANEL: match the actual visible 5 and * buttons in the screenshot.
# The 5 is the upper button and * is the lower button.
old5 = 'if (hit(px, ny, 0.41f, 0.63f, 0.14f, 0.14f)) return Canvas.KEY_NUM5;'
new5 = 'if (hit(px, ny, 0.66f, 0.70f, 0.17f, 0.14f)) return Canvas.KEY_NUM5;'
if old5 not in s:
    raise SystemExit('5 mapping not found in base implementation')
s = s.replace(old5, new5, 1)

old6 = 'if (hit(px, ny, 0.46f, 0.80f, 0.14f, 0.14f)) return Canvas.KEY_STAR;'
new6 = 'if (hit(px, ny, 0.72f, 0.90f, 0.18f, 0.13f)) return Canvas.KEY_STAR;'
if old6 not in s:
    raise SystemExit('* mapping not found in base implementation')
s = s.replace(old6, new6, 1)

p.write_text(s)
PY
