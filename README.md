# graphos-studio

Frontend of Graphos, split out of the Haskell monorepo (openspec change
`split-graphos-studio` in the Graphos repo). Three deliverables live here:

- **Graphos Studio** — a standalone Elm workbench for Graphos graphs (spec:
  `elm-graph-studio` in the Graphos repo). Load a `graph.json` (drag-and-drop,
  offline) or connect to `graphos serve`; navigate (LOD overview → community →
  node, deep links, browser Back/Forward, breadcrumb, Escape), edit nodes and
  edges with undo/redo, define Obsidian-style query+color groups, and extract
  subgraphs to the `json-graph-web-view` canonical shape (drop the download into
  `graphos-out/views/` and the views catalog serves it).
- **HTML viewer assets** — `viewer.js`, `viewer.css` and the vendored
  vis-network renderer, served at runtime by `graphos serve` from the bundle
  built here (no longer embedded into the Haskell binary at compile time).
- **`openspec-view` package** — the `graphos view` backend (OpenSpec change
  list, artifact view, spec diff, state dashboard) as a standalone `base`-only
  Haskell package, `openspec-view/openspec-view.cabal`. It reads an
  `openspec/` workspace; the `graphos` executable depends on it as a normal
  package instead of an in-repo sub-library.

The only boundary with the Haskell repo is the `graph-json-contract` shape and
the `graphos serve` slice/query API; both are consumed unchanged.

## Dev stack

`devenv up` starts the studio, the Graphos query API and the mnemo console from
the artifacts pinned in `dev-stack/pins.json`:

```bash
direnv allow                       # or: devenv shell
devenv tasks run dev-stack:check   # preflight: pins, cache, config, graph, ports
devenv up                          # Ctrl-C stops it
```

| Service | Address |
|---|---|
| Studio | <http://127.0.0.1:8090/> |
| Graphos | <http://127.0.0.1:8080/graph.json> · query API `/api/query` |
| mnemo console | <http://127.0.0.1:7482/> (open the tokenised URL the log prints) |

The Graphos v0.3.0 release serves `/graph.json` and `/api/query`; it has no
`/api/overview` slice API, so the studio connects in its legacy mode. The
studio's default origin is `http://localhost:8080`; on a host where the browser
does not fall back from `::1`, use `http://127.0.0.1:8080`. For a background
run use `devenv processes start`, and `devenv processes down` to stop it.

### Pins and cache

`dev-stack/pins.json` is the single record of what runs:

- **graphos**: GitHub release `v0.3.0`, asset `graphos-linux-x86_64`, verified
  against the published `.sha256`.
- **mnemo**: source pin `jeremiepas/poc-graphos` at
  `d5d7b6e3cb66e46b8cc52d854cdd00e083b36cbe`, built once from `mnemo/` with the
  shell's GHC, then verified against a recorded sidecar hash.

Bump a pin by editing `dev-stack/pins.json` and running
`devenv tasks run dev-stack:fetch`. An already verified artifact is reused and
never downloaded or rebuilt again. The cache lives in `.devenv/dev-stack/`
(gitignored, removed by `devenv clean`) and is laid out per version, so a pin
change coexists with the previous artifact. A SHA-256 mismatch removes the
artifact and fails closed: the service does not start.

### Configuration

| Variable | Default | Used by |
|---|---|---|
| `GRAPHOS_CONFIG` | `$HOME/.config/graphos/graphos.yaml` | graph building only |
| `MNEMO_CONFIG` | `$HOME/.config/mnemo/graphos-studio.yaml` | `mnemo up`, `mnemo web` |

Both are exported in the dev shell and resolved again by the service wrappers,
so an exported value wins and the repository does not need editing.
`graphos serve` takes flags, not a configuration file: the stack passes
`--graph`, `--dir`, `--port` and `--host` and documents that `GRAPHOS_CONFIG`
is the graph builder's configuration. The mnemo path is passed explicitly to
`mnemo up` and `mnemo web`, and must exist.

### Graph

`GRAPHOS_GRAPH` wins; otherwise `graphos-out/graph.json` when it exists; then
`tests/fixtures/graph.json`, so a clean checkout still starts connected. The
selected graph is published as `/graph.json`. The checked-in contract fixture
uses numeric `community_aggregates` ids and only the contract fields, which the
pinned server cannot decode, so that section is dropped from the published copy;
the studio synthesizes aggregates from node community ids. When no graph
exists, the Graphos process exits with a message naming `GRAPHOS_GRAPH` and both
candidate paths.

### Without the stack

The individual commands remain available:

```bash
# devenv provides elm 0.19.2, elm-test, elm-format, elm-review:
elm make src/Main.elm --optimize --output=public/studio.js
elm-test
python3 -m http.server --bind 127.0.0.1 -d public 8090   # → http://127.0.0.1:8090
```

`devenv` tasks mirror CI: `devenv tasks run studio:ci` (both Elm entries,
tests, `elm-review`, fixture drift, the Mnemo entry check and token lint). The
Haskell package tests with `devenv tasks run openspec-view:test` (or
`cd openspec-view && cabal test`).

## Mnemo page

`src/Mnemo/Main.elm` is a second Elm entry, the read-only Mnemo page
(`mnemo-workbench`): a left panel of the console's spaces, each workflow's runs
with status and token use, and the graph of a selected run. It builds to
`public/mnemo/mnemo.js`; `public/mnemo/index.html` starts `Elm.Mnemo` on `#app`
through `boot.js`, so the console's `script-src 'self'` policy holds.

When the console serves a frontend bundle (`mnemo web --frontend-dir
public/mnemo`, from `mnemo-console-in-studio`), `/studio/` is this page. Until
those API changes are applied to the pinned console, open it on the Studio's
own server:

```bash
devenv tasks run mnemo:build
python3 -m http.server --bind 127.0.0.1 -d public 8090   # → http://127.0.0.1:8090/mnemo/
```

The page reads `/api/session` (the spaces, the selected space, the poll
interval and the CSRF token), `/api/runs`, `/api/runs/<run>`,
`/api/runs/<run>/graph` and `/api/step-runs/<step-run>`. Its only write is
`POST /api/session/space` with `X-CSRF-Token`; the selection lives in the
console session, not in the browser. A failed read keeps the last data and
offers a retry; a `401` says the session expired.

## Layout

| Path | What |
|---|---|
| `src/Main.elm` | TEA shell: Model/Msg/update/view, ports wiring |
| `src/Studio/Navigation.elm` | viewer-navigation semantics (invariants mirror the Lean model in the Graphos repo's `openspec/changes/viewer-navigation/lean/`) |
| `src/Studio/Data/Graph.elm` | graph-json-contract types/codecs, aggregate synthesis, BFS, identity fingerprint |
| `src/Studio/Edit.elm` | edit intents, validation, inverses, cypher translation, log |
| `src/Studio/Groups.elm` | query+color groups, first-match-wins, local evaluation |
| `src/Studio/Scope.elm` | extraction scope algebra + canonical view encoder |
| `src/Studio/Api.elm` | graphos serve client: probe, fetch, `/api/cypher/mutate`, group counts |
| `src/Studio/DesignSystem/` | Tokens (single styling source — CI lints hex literals elsewhere) + Components |
| `src/Mnemo/` | the Mnemo page: entry, decoders, grouping, layout and SVG graph |
| `public/` | `index.html`, `ports.js` (renderer handle + localStorage only), vendored vis-network |
| `public/mnemo/` | the Mnemo page's `index.html`, `boot.js` and built `mnemo.js` |
| `assets/viewer/` | static HTML viewer assets (`viewer.css`, `viewer.js`, vendored vis-network) served by `graphos serve` |
| `tests/` | 104 elm-tests: navigation invariants, codecs, editing, groups, scope |
| `review/` | `elm-review` configuration (`NoUnused.Variables`, `Simplify`), run by CI |
| `.scripts/fixture-drift-check.sh` | fails when `tests/fixtures/graph.json` and `Fixtures.fixtureJson` diverge |
| `openspec-view/` | base-only Haskell package behind `graphos view` (change list, artifacts, spec diff, dashboard) |
| `devenv.nix` / `devenv.yaml` | Elm toolchain on the nixpkgs pin that ships Elm 0.19.2, plus GHC/cabal for `openspec-view` |
| `.github/workflows/studio.yml` | build, test, `elm-review`, fixture drift and token lint |
| `.github/workflows/contract.yml` | cross-repo `graph-json-contract` check: decodes real `graph.json` output dispatched by the Graphos `fixture` job |

The contract job is wired to the Haskell repo by a `repository_dispatch`
event (`graph-json-contract`) carrying the `graphos-fixture` files inline.
Set the optional `GRAPHOS_CONTRACT_TOKEN` secret (fine-grained PAT: Actions
read on `jeremiepas/Graphos`) to let push/PR/schedule runs pull the latest
fixture artifact; without it those runs exercise the checked-in placeholder.

## Data sources (2.1–2.3)

The studio resolves one of three implementations at connect time
(`Studio.Data.Source.resolveKind`): `FileSource` (offline), `SlicesMode`
(server ships the slice API — boots from `/api/overview`, never
`graph.json`), or `LegacyMode` (server has no slice API — full fetch, slice
affordances labeled with their unavailability reason). Connection state
(origin + capability badges + graph hash) is shown in the shell; a mid-session
connection loss transitions to `Disconnected` and Retry preserves local work
(groups, undo stack, edit log, scope) rather than wiping it.

### File-mode size guard (`sizeThresholdBytes`)

Refuse files above the ceiling *before* reading, so an oversized file keeps the
tab responsive and recommends connected mode. Pure and shared by the file picker
and drag-drop (`Source.exceedsSizeLimit`).

Measured on the reference machine (Node harness, `JSON.parse` as a proxy for the
Elm `Json.Decode` run atop the same bytes):

| Size        | Nodes  | Parse (best) | Parse (avg) | Peak RSS |
|-------------|--------|--------------|-------------|----------|
| 43.4 MB     | 402,764 | 206 ms      | 216 ms      | ~482 MB  |

A ~40 MB offline file decodes well under a sub-second responsiveness bar, so the
100 MB ceiling is retained: files up to 100 MB are accepted offline and anything
larger is refused before any read. Cabal-driven fixture regeneration lives in W7
(AVI-752); this ceiling is set from the data above, not arbitrarily.

## Editing semantics

- **Connected**: optimistic apply → `/api/cypher/mutate` (`cypher-mutation`
  subset, `persist: true`); server rejection reverts via the inverse intent.
- **File mode**: identity-keyed edit log (localStorage), replay offered on
  reload, export as contract `graph.json` + changelog.
