## Why

A developer who clones the studio has to run three programs by hand: `elm make`
plus a static file server for the SPA, `graphos serve` from a separate checkout,
and the mnemo console through a wrapper that exports `MNEMO_CONFIG`. Nothing
records which version of Graphos or mnemo the studio was tried against, and the
three services read configuration from different places, so a fresh checkout is
neither reproducible nor quick to bring up.

The pieces now exist but are unpinned: Graphos publishes a release binary
(`v0.3.0`, `graphos-linux-x86_64` with a SHA-256), mnemo has no GitHub release
and must be built from a pinned `poc-graphos` commit, and the studio space's
configuration already lives at `~/.config/mnemo/graphos-studio.yaml`. A single
`devenv up` that fetches verified, pinned services and points them at explicit
user-home configuration paths makes the studio reproducible and keeps the dev
stack in step with the releases.

## What Changes

- Add a `devenv up` dev stack with three supervised processes: the studio
  frontend (build `public/studio.js`, serve it on 8090), `graphos serve` (query
  API on 8080) and the mnemo web console (7482) backed by its Neo4j memory
  graph.
- Record every service version in a checked-in pin manifest and obtain it
  idempotently: Graphos from its GitHub release tag/asset/SHA-256, mnemo from a
  pinned `poc-graphos` commit built once into the devenv cache. **Note:**
  `poc-graphos` publishes no release binary today; the manifest supports a
  release pin so switching mnemo to an asset is a one-line change when one
  exists.
- Verify the SHA-256 of every fetched artifact before it runs, fail closed on a
  mismatch, and reuse the cache on the next `devenv up`.
- Add explicit configuration paths, each overridable by an environment variable
  and defaulting under the user's home: `GRAPHOS_CONFIG`
  (`~/.config/graphos/graphos.yaml`) and `MNEMO_CONFIG`
  (`~/.config/mnemo/graphos-studio.yaml`). `graphos serve` takes flags rather
  than a config file, so the stack passes `--graph`, `--dir`, `--port` and
  `--host` explicitly and documents that `GRAPHOS_CONFIG` governs graph
  building, not serving. Static files are served because the pinned v0.3.0
  server has no `/api/overview` slice API: the studio probes `/api/query` and
  fetches `/graph.json`, so it connects in its legacy mode.
- Choose the served graph from `GRAPHOS_GRAPH`, defaulting to
  `graphos-out/graph.json` when it exists and `tests/fixtures/graph.json`
  otherwise, so a clean checkout still starts connected. The contract fixture
  is published under the pinned server's legacy shape (its numeric
  `community_aggregates` ids are decoded as text by v0.3.0 and rejected; the
  studio synthesizes aggregates from node community ids).
- Add a `devenv tasks run dev-stack:check` preflight and a README "Dev stack"
  section that replaces the manual three-terminal recipe.
- Out of scope (stated so the proposal is not read as wider): publishing a
  mnemo release binary from `poc-graphos`, live frontend reload, hosts other
  than Linux x86_64, and production deployment.

## Capabilities

### New Capabilities

- `dev-stack`: one-command, version-pinned startup of the studio frontend and
  the Graphos and mnemo services, with explicit configuration paths and a
  preflight that proves the stack is ready.

### Modified Capabilities

## Impact

- `devenv.nix`: add `processes`, configuration defaults and the
  `dev-stack:fetch` and `dev-stack:check` tasks; add `curl`, `jq`, `git`, `gh`
  and `pkg-config` to the packages used by the fetch and verification scripts.
- New `dev-stack/pins.json` and `scripts/dev-stack/*.sh` (fetch/verify, service
  wrappers, preflight).
- `.gitignore`: fetched artifacts live under the already-ignored `.devenv/`
  cache; no new ignore rule expected.
- `README.md`: "Build & run" gains the one-command path and the configuration
  and graph overrides.
- External reads only: `jeremiepas/Graphos` release `v0.3.0`, and a
  `jeremiepas/poc-graphos` checkout at the pinned commit for the mnemo build.
- No change to the studio runtime, the Graphos repository, or the mnemo
  repository.
