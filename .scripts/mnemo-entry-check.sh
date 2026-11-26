#!/usr/bin/env bash
# `mnemo-workbench` 2.1: the Mnemo entry is a second Elm program, and the page
# it ships starts `Elm.Mnemo.Main` on the `app` node. A missing or renamed entry
# fails this check before the console serves a blank page.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

test -f src/Mnemo/Main.elm || { echo "missing src/Mnemo/Main.elm" >&2; exit 1; }
test -f public/mnemo/index.html || { echo "missing public/mnemo/index.html" >&2; exit 1; }
test -f public/mnemo/boot.js || { echo "missing public/mnemo/boot.js" >&2; exit 1; }

grep -q 'src="mnemo.js"' public/mnemo/index.html \
  || { echo "public/mnemo/index.html does not load mnemo.js" >&2; exit 1; }
grep -q 'src="boot.js"' public/mnemo/index.html \
  || { echo "public/mnemo/index.html does not load boot.js" >&2; exit 1; }
grep -q 'Elm.Mnemo.Main.init' public/mnemo/boot.js \
  || { echo "public/mnemo/boot.js does not start Elm.Mnemo.Main" >&2; exit 1; }
grep -q 'getElementById("app")' public/mnemo/boot.js \
  || { echo "public/mnemo/boot.js does not mount on #app" >&2; exit 1; }

echo "OK: public/mnemo/index.html starts Elm.Mnemo.Main on #app"
