#!/usr/bin/env bash
# Preflight for `devenv up`: prove the stack is ready before starting it.
#
# Every check is reported, not fatal, so one run lists every problem with a
# remediation hint. Exit 0 only when all checks pass.
set -uo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

failures=0

section() {
  printf '\n%s\n' "$*"
}

ok() {
  printf '  ok    %s\n' "$*"
}

warn() {
  printf '  note  %s\n' "$*"
}

fail() {
  printf '  FAIL  %s\n' "$*" >&2
  failures=$((failures + 1))
}

section "pin manifest"
if [ ! -r "$PINS_FILE" ]; then
  fail "pin manifest missing: $PINS_FILE"
else
  manifest_query='(.graphos.kind == "release")
    and (.graphos.repo | type == "string")
    and (.graphos.version | type == "string")
    and (.graphos.asset | type == "string")
    and (.graphos.sha256 | test("^[0-9a-f]{64}$"))
    and (.mnemo.kind == "source")
    and (.mnemo.repo | type == "string")
    and (.mnemo.rev | test("^[0-9a-f]{40}$"))
    and (.mnemo.subdir | type == "string")
    and (.mnemo.version | type == "string")'
  if jq -e "$manifest_query" "$PINS_FILE" >/dev/null 2>&1; then
    ok "$PINS_FILE has a release pin for graphos and a source pin for mnemo"
  else
    fail "$PINS_FILE is not valid or is missing a graphos/mnemo pin field; see dev-stack/pins.json"
  fi
fi

section "cached artifacts"
fetch_hint="run: devenv tasks run dev-stack:fetch"

graphos_version="$(jq -r '.graphos.version // empty' "$PINS_FILE" 2>/dev/null)"
graphos_sha="$(jq -r '.graphos.sha256 // empty' "$PINS_FILE" 2>/dev/null)"
if [ -z "$graphos_version" ] || [ -z "$graphos_sha" ]; then
  fail "cannot read the graphos pin from $PINS_FILE"
else
  graphos_artifact="$ARTIFACTS_DIR/graphos/$graphos_version/graphos"
  if [ ! -f "$graphos_artifact" ]; then
    fail "graphos $graphos_version is not cached at $graphos_artifact ($fetch_hint)"
  elif hash_matches "$graphos_artifact" "$graphos_sha"; then
    ok "graphos $graphos_version matches its pinned SHA-256"
  else
    fail "graphos $graphos_version does not match the pin $graphos_sha ($fetch_hint)"
  fi
fi

mnemo_rev="$(jq -r '.mnemo.rev // empty' "$PINS_FILE" 2>/dev/null)"
if [ -z "$mnemo_rev" ]; then
  fail "cannot read the mnemo pin from $PINS_FILE"
else
  mnemo_artifact="$ARTIFACTS_DIR/mnemo/$mnemo_rev/mnemo"
  mnemo_sidecar="$ARTIFACTS_DIR/mnemo/$mnemo_rev/mnemo.sha256"
  if [ ! -f "$mnemo_artifact" ]; then
    fail "mnemo $mnemo_rev is not cached at $mnemo_artifact ($fetch_hint)"
  elif [ ! -f "$mnemo_sidecar" ]; then
    fail "mnemo $mnemo_rev has no hash sidecar at $mnemo_sidecar ($fetch_hint)"
  else
    expected="$(awk 'NR == 1 {print $1}' "$mnemo_sidecar")"
    if hash_matches "$mnemo_artifact" "$expected"; then
      ok "mnemo $mnemo_rev matches its recorded SHA-256"
    else
      fail "mnemo $mnemo_rev does not match its sidecar $mnemo_sidecar ($fetch_hint)"
    fi
  fi
fi

section "configuration"
if [ -f "$MNEMO_CONFIG" ]; then
  ok "MNEMO_CONFIG=$MNEMO_CONFIG exists"
else
  fail "MNEMO_CONFIG=$MNEMO_CONFIG is missing; create the space configuration or export MNEMO_CONFIG to an existing file"
fi

if [ -f "$GRAPHOS_CONFIG" ]; then
  ok "GRAPHOS_CONFIG=$GRAPHOS_CONFIG exists (optional: graph building)"
else
  warn "GRAPHOS_CONFIG=$GRAPHOS_CONFIG is absent (optional: graphos serve takes flags, not a configuration file)"
fi

section "graph"
if graph_message="$(resolve_graph 2>&1)"; then
  ok "serving $graph_message"
else
  fail "$graph_message"
fi

section "ports"
# Bind and close each port from Python: no extra package and no parsing of ss.
port_check() {
  local port="$1" service="$2" output
  if output="$(python3 - "$port" <<'PY' 2>&1
import socket
import sys

port = int(sys.argv[1])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    sock.bind(("127.0.0.1", port))
except OSError as exc:
    print(exc)
    sys.exit(1)
finally:
    sock.close()
PY
  )"; then
    ok "port $port ($service) is free"
  else
    fail "port $port ($service) is not available: $output; stop the process holding it"
  fi
}

port_check "$STUDIO_PORT" "studio"
port_check "$GRAPHOS_PORT" "graphos"
port_check "$MNEMO_PORT" "mnemo"

if [ "$failures" -gt 0 ]; then
  printf '\ndev-stack: %d preflight check(s) failed\n' "$failures" >&2
  exit 1
fi

cat <<EOF

dev-stack: ready
  studio  http://127.0.0.1:$STUDIO_PORT/
  graphos http://127.0.0.1:$GRAPHOS_PORT/graph.json  (API: /api/query)
  mnemo   http://127.0.0.1:$MNEMO_PORT/  (open the tokenised URL the console prints)
EOF
