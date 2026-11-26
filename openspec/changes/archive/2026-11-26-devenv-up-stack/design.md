## Context

See `proposal.md` — Why. The constraints that shape the approach:

- `devenv` 2.1.2 already provides the Elm 0.19.2 toolchain from the nixpkgs pin
  in `devenv.yaml`, and `ghc`/`cabal` for `openspec-view` — the shell's GHC is
  9.10.3, the same major version the mnemo pin was built with.
- The studio is static: `elm make src/Main.elm --optimize --output=public/studio.js`,
  then any static server over `public/`. `src/Main.elm` defaults its Graphos
  origin to `http://localhost:8080`.
- `graphos serve` takes flags, not a configuration file: `--graph`, `--dir`,
  `--port`, `--host`, `--api-only`. It loads the graph at startup and exits 1
  when the file is missing. It answers with `Access-Control-Allow-Origin: *`, so
  a studio served from another origin can call it. The pinned v0.3.0 release
  ships `/api/query`, `/api/explain`, `/api/path`, `/api/symbols`,
  `/api/neighbors`, `/api/cypher/mutate` and static files, but no
  `/api/overview` slice API; the studio's probe therefore falls back to
  `LegacyMode`, which fetches `/graph.json` and uses `/api/query`. Serving
  static files (no `--api-only`) is what makes a fresh clone connect.
- Graphos publishes `v0.3.0` with `graphos-linux-x86_64` and a `.sha256`
  (`c3894f8614c3458431ccb04d2ada29ec54aa130be4603156e89b637e81000892`).
- mnemo publishes no release. The `graphos-studio` space is configured at
  `~/.config/mnemo/graphos-studio.yaml` (console 7482, memory graph at
  `localhost:7477`); `mnemo up` is idempotent, and `mnemo web` binds only
  `127.0.0.1`. The mnemo package lives under `mnemo/` in
  `jeremiepas/poc-graphos`.
- `graphos.yaml` is read by graph-building commands (global
  `~/.config/graphos/graphos.yaml`, then project `./graphos.yaml`); `serve`
  ignores it.
- `tests/fixtures/graph.json` is a checked-in 12-node graph. The studio repo has
  no `graphos-out/`, and `.devenv/` is already gitignored.

## Goals / Non-Goals

**Goals:**

- One `devenv up` reaches a connected studio and a live mnemo console, with
  supervised logs and a clean stop (`Ctrl-C`, or `devenv processes start` then
  `devenv processes down` for a background run).
- The versions of Graphos and mnemo are visible in one checked-in file and are
  verified before use.
- Configuration paths are explicit, default under the user's home, and
  overridable without editing the repository.
- A preflight proves the stack is ready and names the fix when it is not.

**Non-Goals:**

- Publishing a mnemo release binary (the user chose a source pin for now; the
  manifest accepts a release pin later).
- Live frontend reload / a file watcher; production deployment; TLS; remote
  binds; platforms other than Linux x86_64.
- Building Graphos from source, or managing Neo4j beyond `mnemo up`.
- Changing the studio runtime, the Graphos API or the mnemo CLI.

## Decisions

### 1. `devenv` processes, not a Makefile or Compose file

`devenv.nix` gains a `processes` block with `studio`, `graphos` and `mnemo`.
`devenv up` supervises them in the foreground and prefixes their logs; Ctrl-C
stops it. `devenv processes start` plus `devenv processes down` is the
background pair.

Alternatives rejected: a `docker-compose.yml` would duplicate the toolchain and
bind-mount Elm/GHC; a `scripts/dev.sh` would have no supervision, restart
semantics or multiplexed logs; a flake app would not use the devenv shell the
studio already standardizes on.

### 2. A checked-in pin manifest with one fetch wrapper per service

`dev-stack/pins.json` records:

```json
{
  "graphos": {
    "kind": "release",
    "repo": "jeremiepas/Graphos",
    "version": "v0.3.0",
    "asset": "graphos-linux-x86_64",
    "sha256": "c3894f8614c3458431ccb04d2ada29ec54aa130be4603156e89b637e81000892"
  },
  "mnemo": {
    "kind": "source",
    "repo": "jeremiepas/poc-graphos",
    "rev": "d5d7b6e3cb66e46b8cc52d854cdd00e083b36cbe",
    "subdir": "mnemo",
    "version": "0.1.0.0"
  }
}
```

`scripts/dev-stack/graphos.sh` and `mnemo.sh` each ensure their own artifact,
then `exec` the service. They run concurrently, so neither waits on the other;
there is no separate fetch process whose exit process-compose must interpret.
A `dev-stack:fetch` task runs the same ensure functions ahead of time for a
first-run build or an offline check.

Alternatives rejected: one global fetch process with `depends_on` (a process
that exits before the servers is awkward in process-compose); fetching on every
`devenv up` without a cache (slow and rate-limited); Nix flake inputs for both
projects (Graphos has a published asset, and the user asked for pinned binary
versions, not a local Haskell build).

### 3. mnemo is a source pin built once into the cache

The user chose to build the pinned commit rather than publish a release first.
The fetch script:

1. uses `MNEMO_SRC` when set (an existing `poc-graphos` checkout), after
   checking `git rev-parse HEAD` equals the pin;
2. otherwise `gh repo clone jeremiepas/poc-graphos` into the cache with the
   developer's existing `gh` authentication (no token is stored), then checks
   out the pinned revision;
3. runs `cabal build exe:mnemo` in `<src>/mnemo` with the devenv's GHC 9.10.3
   and `cabal list-bin exe:mnemo`, then copies the binary into the cache and
   writes its SHA-256 sidecar.

The commit is the reproducibility anchor; the sidecar hash detects a corrupted
cache. The manifest's `kind` switches to `"release"` (tag + asset + sha256) once
`poc-graphos` publishes a binary, and the build step disappears.

Alternatives rejected: a `MNEMO_BIN` path only (not reproducible on a fresh
machine); a second nixpkgs input for a newer GHC (the studio shell already has
9.10.3); publishing a mnemo release now (a separate change in `poc-graphos`,
not selected).

### 4. Configuration paths resolved at runtime, with user-home defaults

Both service wrappers and `enterShell` use shell defaults:

```sh
: "${GRAPHOS_CONFIG:=$HOME/.config/graphos/graphos.yaml}"
: "${MNEMO_CONFIG:=$HOME/.config/mnemo/graphos-studio.yaml}"
```

so an exported value wins, `enterShell` shows the resolved paths, and the
process wrappers still work if a process is launched without an interactive
shell. `mnemo up` and `mnemo web` receive `--config "$MNEMO_CONFIG"` explicitly.
`graphos serve` receives `--graph/--dir/--port/--host`; the README states
that `GRAPHOS_CONFIG` is the graph builder's configuration, since `serve` does
not read it.

Alternatives rejected: `env` values in `devenv.nix` (they would freeze at
evaluation time and override an exported value); a project `graphos.yaml`
(`serve` ignores it); adding a `--config` flag to Graphos (a Haskell change in
another repository, out of scope).

### 5. Graph selection: explicit, then real output, then fixture

`GRAPHOS_GRAPH` wins; otherwise `graphos-out/graph.json` if it exists; otherwise
`tests/fixtures/graph.json`. If the explicit value or neither default exists,
the Graphos wrapper exits with a message naming the variable and both
candidates. `graphos serve` itself already exits 1 on a missing file, so the
wrapper adds the actionable message and the selection rule.

The selected graph is published at `.devenv/dev-stack/graphos-serve/graph.json`
and passed to `serve` together with `--dir` on that directory, so the studio can
fetch it. The checked-in contract fixture is copied without its
`community_aggregates`: v0.3.0 decodes aggregate ids as `Text` and requires the
eleven analysis fields, while the fixture carries numeric ids and the seven
contract fields, so the server rejects it. Dropping that section is lossless for
the studio, which synthesizes aggregates from node `community_id`s and
`community_labels`; a real `graphos-out` graph has string ids and is symlinked
unchanged.

Alternatives rejected: always the fixture (ignores the developer's real graph);
require `GRAPHOS_GRAPH` (a fresh clone would not start); build a graph on
startup (slow and needs a Graphos run).

### 6. Build and serve the studio in one process

The `studio` process runs the same optimized `elm make` as CI, then
`exec python3 -m http.server --bind 127.0.0.1 -d public 8090`. A compile error
exits before the server binds. `python3` is already in the shell for the fixture
drift check.

Alternatives rejected: `elm reactor` (no optimized bundle, different routing);
a Node dev server (no Node toolchain in the pin); `elm-watch` (not in the pinned
nixpkgs; live reload is a follow-up); a separate build task the user must
remember.

### 7. Cache under `.devenv/dev-stack/`

```
.devenv/dev-stack/
  artifacts/graphos/v0.3.0/{graphos,graphos.sha256}
  artifacts/mnemo/<rev>/{mnemo,mnemo.sha256}
  src/poc-graphos-<rev>/
```

It is repo-local, already ignored, and removed by `devenv clean`. Per-version
directories let a pin change coexist with the old artifact.

Alternatives rejected: `~/.cache` (survives `devenv clean`, shared across clones,
less obvious); `/tmp` (not durable).

### 8. Fail-closed verification

Release assets are downloaded to a temporary directory, checked with
`sha256sum -c` against the published `.sha256`, then moved into the cache.
Locally built binaries are built to a temporary path, hashed, moved, and their
sidecar checked before every run. A mismatch removes the artifact and exits
non-zero; there is no `--insecure` switch.

### 9. Neo4j stays behind `mnemo up`

The `mnemo` process calls `mnemo up --config "$MNEMO_CONFIG"` (idempotent) and
only then `exec`s `mnemo web`. If the memory graph cannot start, the process
exits with mnemo's diagnostic and no console is bound.

Alternatives rejected: a separate `neo4j` process (duplicates mnemo's memory
configuration and credentials); assuming the developer ran `mnemo up` (breaks
the one-command promise).

### 10. Preflight with Python port checks

`scripts/dev-stack/check.sh` reads the pins with `jq`, verifies the cached
artifacts and sidecars, requires `MNEMO_CONFIG` to exist, reports
`GRAPHOS_CONFIG` when absent (it is optional), resolves the graph, and tries to
bind 127.0.0.1:8090, 8080 and 7482 with a short Python `socket` snippet. It
prints the three URLs on success and a remediation line per failure. The
`dev-stack` task runs it; no CI job is added because the studio CI does not
provision devenv.

Alternatives rejected: `ss`/`lsof` (extra package, parsing); skipping the port
check (the most common first-run failure).

### 11. Linux x86_64 guard

The Graphos release asset exists only for `linux-x86_64`. The wrapper checks
`uname -s`/`uname -m` before fetching and exits with a message naming the
supported platform. Supporting other hosts would need a different asset and is
a non-goal.

## Risks / Trade-offs

- **Private mnemo source needs authentication.** → `MNEMO_SRC` for an existing
  checkout, or `gh auth login`; the error names both. No token is stored.
- **The first mnemo build is slow and needs Hackage.** → the cache keeps it to
  once per pin; `dev-stack:fetch` makes it an explicit step; `cabal update` is
  run only when the package index is absent.
- **A C dependency may be missing from the studio shell.** → add
  `pkg-config`/`zlib`/`openssl` in the change if the build proves it; the same
  GHC 9.10.3 that builds mnemo in `poc-graphos` is in this shell.
- **GitHub rate limits or offline.** → a verified cache starts without network;
  the error names `devenv tasks run dev-stack:fetch`.
- **The fixture is only 12 nodes.** → `GRAPHOS_GRAPH` or a `graphos-out/` build
  gives the real graph; the fallback exists so a fresh clone is connected.
- **`localhost` in the studio vs `127.0.0.1` on the server.** → `graphos serve`
  binds 127.0.0.1 and the studio's default origin is `http://localhost:8080`;
  browsers fall back from `::1`, and the README gives `http://127.0.0.1:8080`
  for the rare host that does not.
- **Port collisions.** → the preflight tries to bind all three before
  `devenv up` starts.
- **`mnemo web` prints a tokenised URL.** → the README says to use the URL the
  console prints; the plain 7482 root is not the authenticated entry point.
- **A failed service must not spin.** → each process sets
  `process-compose.restart = "no"`, so a failed process stays failed with its
  log in view; `devenv up` again retries. This is preferred over a restart loop
  hiding a compile error or an occupied port.

## Migration Plan

Additive: add the manifest, scripts, processes and task; update the README.
Rollback is removing the `processes` block and the `dev-stack/` and
`scripts/dev-stack/` additions; `devenv clean` drops the cache. No data or API
migration.

## Open Questions

- Should a later change add a live-reload watcher for the studio? It does not
  change the specs or the approach; the process can grow a watcher without a
  contract change.
- Should `poc-graphos` publish `mnemo-linux-x86_64` so the source pin becomes a
  release pin? The manifest already supports it; it is a follow-up in that
  repository, not a blocker here.
- Should CI run `dev-stack:check`? It needs devenv and GitHub access; the local
  task covers the first iteration.
