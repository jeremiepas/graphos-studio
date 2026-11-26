#!/usr/bin/env bash
# Serve the selected graph with the pinned Graphos release binary.
#
# `graphos serve` takes flags, not a configuration file. GRAPHOS_CONFIG is
# still exported and printed because it governs graph *building* in the same
# shell; the API below is configured entirely by the flags.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

require_linux_x86_64

# Resolve the graph before downloading 100+ MB: a missing GRAPHOS_GRAPH should
# fail with the selection rule, not after a long fetch.
graph="$(resolve_graph)"

"$script_dir/fetch-graphos.sh"

version="$(pin '.graphos.version')"
expected="$(pin '.graphos.sha256')"
artifact="$ARTIFACTS_DIR/graphos/$version/graphos"
verify_pinned_sha256 "$artifact" "$expected" "graphos $version"

# `graphos serve` reads the graph but serves `/graph.json` from `--dir`. The
# studio (legacy mode, no slice API on this pin) fetches both `/graph.json` and
# `/api/query`, so the selected graph is published under a stable directory.
serve_dir="$CACHE_ROOT/graphos-serve"
served_graph="$serve_dir/graph.json"
mkdir -p -- "$serve_dir"

# The studio's contract fixture uses numeric community ids and only the seven
# contract fields, which the pinned server's legacy `CommunityAggregate`
# decoder rejects. Drop the aggregates from the served copy; the studio
# synthesizes them from node community ids and `community_labels`. A real
# `graphos-out` graph (string ids) is served unchanged.
if jq -e '(.community_aggregates | type == "array") and ((.community_aggregates[0].id? // null) | type == "number")' "$graph" >/dev/null 2>&1; then
  note "normalizing $graph for the pinned server (community_aggregates are synthesized by the studio)"
  tmp_graph="$served_graph.tmp.$$"
  jq 'del(.community_aggregates)' "$graph" > "$tmp_graph"
  mv -f -- "$tmp_graph" "$served_graph"
else
  ln -sfn -- "$graph" "$served_graph"
fi

note "graph=$graph"
note "serving http://$GRAPHOS_HOST:$GRAPHOS_PORT/graph.json and /api/query (GRAPHOS_CONFIG=$GRAPHOS_CONFIG governs graph building, not serve)"
exec "$artifact" serve --graph "$served_graph" --dir "$serve_dir" --port "$GRAPHOS_PORT" --host "$GRAPHOS_HOST"
