#!/usr/bin/env bash
# Bring up the mnemo memory graph, then serve the console on 127.0.0.1:7482.
#
# `mnemo up` is idempotent and owns the Neo4j memory graph, so the console is
# never started against an absent graph: a failure exits before the exec.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

"$script_dir/fetch-mnemo.sh"

rev="$(pin '.mnemo.rev')"
artifact="$ARTIFACTS_DIR/mnemo/$rev/mnemo"
verify_sidecar "$artifact" "$ARTIFACTS_DIR/mnemo/$rev/mnemo.sha256" "mnemo $rev"

[ -f "$MNEMO_CONFIG" ] \
  || die "MNEMO_CONFIG=$MNEMO_CONFIG does not exist; create the space configuration or export MNEMO_CONFIG to an existing file"

note "mnemo up --config $MNEMO_CONFIG"
"$artifact" up --config "$MNEMO_CONFIG" \
  || die "'mnemo up --config $MNEMO_CONFIG' failed; no console is started"

note "serving the console at http://$MNEMO_HOST:$MNEMO_PORT/ (open the tokenised URL printed below)"
exec "$artifact" web --config "$MNEMO_CONFIG" --host "$MNEMO_HOST" --port "$MNEMO_PORT"
