#!/usr/bin/env bash
# Shared helpers for the devenv dev stack.
#
# Sourced by the wrappers in this directory. It deliberately does not change
# the caller's shell options: each entry point chooses its own `set` flags.
# The contract it encodes:
#
#   * artifacts live in the repo-local, gitignored `.devenv/dev-stack` cache;
#   * configuration paths default under $HOME and an exported value wins;
#   * the served graph is GRAPHOS_GRAPH, then graphos-out/graph.json, then
#     tests/fixtures/graph.json;
#   * every artifact is verified with SHA-256 before it runs (fail closed).

DEV_STACK_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$DEV_STACK_SCRIPT_DIR/../.." && pwd)"

PINS_FILE="$REPO_ROOT/dev-stack/pins.json"
CACHE_ROOT="$REPO_ROOT/.devenv/dev-stack"
ARTIFACTS_DIR="$CACHE_ROOT/artifacts"
SRC_DIR="$CACHE_ROOT/src"
BIN_DIR="$CACHE_ROOT/bin"

STUDIO_PORT=8090
GRAPHOS_PORT=8080
GRAPHOS_HOST=127.0.0.1
MNEMO_PORT=7482
MNEMO_HOST=127.0.0.1

# A value exported by the developer wins; otherwise the path is the one the
# README documents under the user's home.
: "${GRAPHOS_CONFIG:=$HOME/.config/graphos/graphos.yaml}"
: "${MNEMO_CONFIG:=$HOME/.config/mnemo/graphos-studio.yaml}"
export GRAPHOS_CONFIG MNEMO_CONFIG

# All diagnostics go to stderr so a wrapper's stdout stays a service stream.
note() {
  printf 'dev-stack: %s\n' "$*" >&2
}

die() {
  printf 'dev-stack: %s\n' "$*" >&2
  exit 1
}

# Read one value from the checked-in pin manifest. `-e` makes a missing or null
# value fatal instead of printing the string "null".
pin() {
  local query="$1"
  [ -r "$PINS_FILE" ] || die "pin manifest not found: $PINS_FILE"
  jq -er "$query" "$PINS_FILE" 2>/dev/null \
    || die "pin manifest $PINS_FILE has no value at $query"
}

# The Graphos release asset exists for Linux x86_64 only (design decision 11).
require_linux_x86_64() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  if [ "$os" != "Linux" ] || [ "$arch" != "x86_64" ]; then
    die "unsupported platform $os/$arch: Graphos publishes only graphos-linux-x86_64 (Linux x86_64); this stack does not cross-build"
  fi
}

sha256_of() {
  sha256sum -- "$1" | cut -d ' ' -f1
}

hash_matches() {
  local file="$1" expected="$2"
  [ "$(sha256_of "$file")" = "$expected" ]
}

# Verify a file against a hash known ahead of time (a release pin, or the
# published .sha256). Never removes the file: callers decide whether a bad
# artifact is evicted.
verify_pinned_sha256() {
  local file="$1" expected="$2" label="$3" actual
  [ -f "$file" ] || die "$label: missing artifact $file"
  actual="$(sha256_of "$file")"
  if [ "$actual" != "$expected" ]; then
    die "$label: SHA-256 mismatch (pin $expected, got $actual); refusing to start from it"
  fi
}

# Verify a locally built artifact against its recorded sidecar. A mismatch is
# cache corruption: remove the artifact and fail closed (design decision 8).
verify_sidecar() {
  local file="$1" sidecar="$2" label="$3" expected actual
  [ -f "$file" ] || die "$label: missing artifact $file"
  [ -f "$sidecar" ] || die "$label: missing hash sidecar $sidecar"
  expected="$(awk 'NR == 1 {print $1}' "$sidecar")"
  actual="$(sha256_of "$file")"
  if [ "$actual" != "$expected" ]; then
    rm -f -- "$file" "$sidecar"
    die "$label: SHA-256 mismatch against $sidecar (expected $expected, got $actual); artifact removed, rerun devenv tasks run dev-stack:fetch"
  fi
}

# Publish a stable path under the cache's bin/ directory for the current pin.
link_artifact() {
  local artifact="$1" name="$2"
  mkdir -p "$BIN_DIR"
  ln -sfn "$artifact" "$BIN_DIR/$name"
}

graph_candidates() {
  printf '%s or %s' "graphos-out/graph.json" "tests/fixtures/graph.json"
}

# Print the selected graph path, or exit non-zero with the rule and the two
# default candidates. An explicit GRAPHOS_GRAPH must exist; the defaults are
# tried in order so a fresh clone still starts connected.
resolve_graph() {
  if [ -n "${GRAPHOS_GRAPH:-}" ]; then
    [ -f "$GRAPHOS_GRAPH" ] \
      || die "GRAPHOS_GRAPH=$GRAPHOS_GRAPH does not exist; set it to an existing graph or use $(graph_candidates)"
    # Absolute so the served-directory symlink stays valid from any cwd.
    printf '%s\n' "$(cd -- "$(dirname -- "$GRAPHOS_GRAPH")" && pwd)/$(basename -- "$GRAPHOS_GRAPH")"
    return 0
  fi

  if [ -f "$REPO_ROOT/graphos-out/graph.json" ]; then
    printf '%s\n' "$REPO_ROOT/graphos-out/graph.json"
  elif [ -f "$REPO_ROOT/tests/fixtures/graph.json" ]; then
    printf '%s\n' "$REPO_ROOT/tests/fixtures/graph.json"
  else
    die "no graph to serve: set GRAPHOS_GRAPH or create $(graph_candidates)"
  fi
}
