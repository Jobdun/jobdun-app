#!/usr/bin/env bash
# Strip unused Phosphor icon-font weights from a built Flutter web bundle.
#
# phosphor_flutter ships 6 font families (~2.6MB). The whole codebase only uses
# PhosphorBold + PhosphorFill (lib/core/theme/app_icons.dart — verified with
# `grep -r PhosphorIcons<weight> lib/`: Regular/Light/Thin/Duotone = 0 refs).
# Icon tree-shaking trims glyphs but still bundles every declared family, so we
# delete the 4 unused .ttf and drop their FontManifest.json entries post-build.
# Safe: nothing references them.
#
# Usage: bash scripts/trim-web-fonts.sh [build/web]
set -euo pipefail
WEB_DIR="${1:-build/web}"
FONT_DIR="$WEB_DIR/assets/packages/phosphor_flutter/lib/fonts"
MANIFEST="$WEB_DIR/assets/FontManifest.json"

[ -d "$WEB_DIR" ] || { echo "trim-web-fonts: $WEB_DIR not found" >&2; exit 1; }

before=$(du -sh "$WEB_DIR" | cut -f1)

# Remove unused weights (keep Phosphor-Bold.ttf + Phosphor-Fill.ttf).
for f in Phosphor.ttf Phosphor-Light.ttf Phosphor-Thin.ttf Phosphor-Duotone.ttf; do
  rm -f "$FONT_DIR/$f"
done

# Drop their FontManifest.json entries so the engine never requests them.
if [ -f "$MANIFEST" ]; then
  python3 - "$MANIFEST" <<'PY'
import json, sys
path = sys.argv[1]
keep = ("PhosphorBold", "PhosphorFill")
with open(path) as fh:
    fonts = json.load(fh)
def keep_entry(e):
    fam = e.get("family", "")
    return any(k in fam for k in keep) if "phosphor_flutter" in fam else True
kept = [e for e in fonts if keep_entry(e)]
with open(path, "w") as fh:
    json.dump(kept, fh)
print(f"  FontManifest.json: {len(fonts)} -> {len(kept)} families")
PY
fi

after=$(du -sh "$WEB_DIR" | cut -f1)
echo "trim-web-fonts: dropped 4 unused Phosphor weights ($before -> $after)"
