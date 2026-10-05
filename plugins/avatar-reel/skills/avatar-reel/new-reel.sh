#!/bin/bash
# Scaffold a new reel build folder from the template.
#   new-reel.sh <slug> [parent-dir]      → <parent-dir>/<slug>-reel   (default parent: the current directory)
set -e
SLUG="$1"; [ -z "$SLUG" ] && { echo "usage: new-reel.sh <slug> [parent-dir]"; exit 1; }
SKILL="$(cd "$(dirname "$0")" && pwd)"
CFG_HOME="${AVATAR_REEL_HOME:-$HOME/.config/avatar-reel}"
[ -f "$CFG_HOME/config.json" ] || { echo "No $CFG_HOME/config.json yet. Run: bash \"$SKILL/setup.sh\" --help"; exit 1; }
[ -d "$CFG_HOME/node_modules/playwright" ] || { echo "Playwright isn't installed in $CFG_HOME. Run setup.sh again."; exit 1; }
DEST="${2:-$PWD}/$SLUG-reel"
[ -e "$DEST" ] && { echo "exists: $DEST (pick another slug or parent dir)"; exit 1; }
mkdir -p "$DEST"/{audio,clips,gfx/out,segs,out}
cp "$SKILL"/template/{reel-lib.mjs,vo.mjs,heygen.mjs,build_gfx.mjs,assemble.mjs,captions.py,timeline.mjs,tighten.py} "$DEST/"
cp "$SKILL/template/gitignore" "$DEST/.gitignore"
cp "$SKILL/template/gfx/gfx.html" "$DEST/gfx/gfx.html"
sed "s#__SLUG__#$SLUG#" "$SKILL/template/reel.config.mjs" > "$DEST/reel.config.mjs"
cp -R "$SKILL/library" "$DEST/lib"          # a private copy, so the reel still builds after the plugin updates
ln -s "$CFG_HOME/node_modules" "$DEST/node_modules"
printf 'Paste the LOCKED script here. Spell for the ear: A.I., numbers as words. Optional [[flat]]...[[/flat]] for a monotone bad-example read.\n' > "$DEST/audio/script.txt"
echo "$DEST"
