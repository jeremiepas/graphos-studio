#!/usr/bin/env bash
# Build the optimized studio bundle, then serve public/ on 127.0.0.1:8090.
#
# The build and the server share one process on purpose: a compile error exits
# non-zero before the static server binds, so a stale public/studio.js is never
# served by `devenv up`.
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

cd "$REPO_ROOT"

note "building public/studio.js (elm make --optimize)"
elm make src/Main.elm --optimize --output=public/studio.js

note "serving http://127.0.0.1:$STUDIO_PORT/ from public/"
exec python3 -m http.server --bind 127.0.0.1 -d public "$STUDIO_PORT"
