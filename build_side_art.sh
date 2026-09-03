#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Reuse the known-good side-art patch, then correct the directional mapping
# to match the actual visible buttons in the supplied layout: the house icon
# is the UP button, while the bottom arrow is DOWN.
curl -fsSL "https://raw.githubusercontent.com/devilhandle/Diamond-Rush/2347ff1267ca4dc067dd600f165fb3c2ffb48230/build_side_art.sh" -o .base_build_side_art.sh
bash .base_build_side_art.sh
rm -f .base_build_side_art.sh

python3 - <<'PY'
from pathlib import Path
p = Path('j2me-loader/app/src/main/java/javax/microedition/shell/MicroActivity.java')
s = p.read_text()
old = 'if (hit(px, ny, 0.48f, 0.51f, 0.095f, 0.09f)) return Canvas.KEY_SOFT_RIGHT;'
new = 'if (hit(px, ny, 0.48f, 0.51f, 0.115f, 0.105f)) return Canvas.KEY_UP;'
if old not in s:
    raise SystemExit('visible UP mapping not found')
s = s.replace(old, new, 1)
old2 = '''                if (hit(px, ny, 0.48f, 0.81f, 0.13f, 0.13f)) return Canvas.KEY_DOWN;\n\n                // The visible UP button is lower than the old touch target.\n                // Move the touch center clearly downward onto the arrow itself.\n                if (hit(px, ny, 0.48f, 0.76f, 0.12f, 0.085f)) return Canvas.KEY_UP;'''
new2 = '''                // The bottom visible arrow is DOWN. Keep its original working\n                // target and do not let an old UP target overlap it.\n                if (hit(px, ny, 0.48f, 0.81f, 0.13f, 0.13f)) return Canvas.KEY_DOWN;'''
if old2 in s:
    s = s.replace(old2, new2, 1)
else:
    # Also handle the latest variant if the base script already has another UP target.
    old3 = 'if (hit(px, ny, 0.48f, 0.82f, 0.13f, 0.105f)) return Canvas.KEY_UP;\n                if (hit(px, ny, 0.48f, 0.90f, 0.12f, 0.075f)) return Canvas.KEY_DOWN;'
    new3 = 'if (hit(px, ny, 0.48f, 0.81f, 0.13f, 0.13f)) return Canvas.KEY_DOWN;'
    if old3 in s:
        s = s.replace(old3, new3, 1)
    else:
        raise SystemExit('directional target block not found')
p.write_text(s)
PY
