## Why

The Mnemo console's API is being extended to serve more than one space and the token use of each
run (`mnemo-console-in-studio` and `console-spaces` in `poc-graphos`), but the Studio still has no
Mnemo view. A person who works in `graphos-studio` and `console` cannot open one page, switch
space, see each workflow's runs with their status and token use, and then open a run to see its
workflow as the graph it is. The Haskell console is one space per page and builds its HTML in
Haskell, which the design system and the tests of this project do not reach.

## What Changes

- **A second Elm entry, the Mnemo page.** `src/Mnemo/Main.elm` builds to `public/mnemo/`, with an
  `index.html` of its own; `mnemo web --frontend-dir public/mnemo` serves it at `/studio/`, while
  the graph Studio keeps `public/index.html` and its bundle. The page uses the design system's
  tokens and the stylesheet the Studio already generates.
- **A spaces panel.** The left panel lists `/api/session.spaces` and marks the selected space;
  clicking a space posts `/api/session/space` with the session's `X-CSRF-Token` and reloads the
  runs of that space. The selection lives in the console session, not in the browser.
- **Workflows, runs, status and token use.** The page groups `/api/runs` by `workflow`; each run
  shows its status, start and end, step count, waiting count, and `tokens.card` / `tokens.prompt`;
  the list refreshes at the session's poll interval while the page is open. An empty space says so.
- **A run's graph.** Clicking a run fetches `/api/runs/<run>/graph` once and `/api/runs/<run>` on
  the poll, and draws a minimal directed graph in SVG: one node per step, placed by its layer, the
  edges, an `implied` edge lighter or dashed, a node coloured by the status the board shows, a
  node with a step run clickable to its status, attempt and token use, and a legend.
- **A page that stays honest when the API fails.** The last data stays, a stale/error banner offers
  a retry, and a `401` says the session expired. The only write is the space selection.
- **Tests and the build.** Decoders against the API fixtures, the grouping, the token formatting
  and the pure layout are `elm-test`; `elm-review` and the CI build the second entry; the design
  system's token lint covers the new modules.

Not in this change: the attention, inbox, run, step-run and delivery pages; removing the Haskell
pages; writes other than the space selection; an editor of workflows; pan and zoom in the graph;
the API itself (it is `console-api` and `console-spaces` in `poc-graphos`).

## Capabilities

### New Capabilities

- `mnemo-workbench`: the Mnemo page of the Studio bundle, its spaces panel, the workflow/run list
  with status and token use, and the read-only graph of a run.

### Modified Capabilities

None. The page is additive; the graph Studio and its graph contract are unchanged.

## Impact

- `src/Mnemo/**` (the entry and its modules), `tests/Mnemo/**` (the fixtures and the tests),
  `public/mnemo/**` (the entry's `index.html` and built `mnemo.js`), `elm.json` (the direct
  `elm/svg` and `elm/time` dependencies), `devenv.nix` (a `mnemo:build` task and `studio:ci`),
  `.github/workflows/studio.yml` (build the entry), `README.md` (the page and the flag).
- `dev-stack/scripts/mnemo.sh` gains `--frontend-dir public/mnemo` when the dev-stack change is in
  `main`; until then the page is opened on the Studio's own server (`python3 -m http.server -d
  public 8090`, `/mnemo/`) and the console serves it after the API changes are applied.
- The page depends on `mnemo-console-in-studio` (`/api/session`, `/api/runs`,
  `/api/runs/<run>/graph`, `--frontend-dir`) and `console-spaces` (`spaces`, the selection, the
  token totals, the two-space fixtures), both in `poc-graphos`. It can be built and tested against
  their fixtures before they are applied; its live check waits for them.
- No new store, credential, port or origin. The page reads the console's own API on the same
  origin, with the session cookie the console sets.

**Measurement.** Measured on 2026-11-26: `graphos-studio` has 104 elm-tests and `elm-review` in
CI (its README and `devenv.nix`); `public/index.html` loads one entry, `studio.js`; `elm.json` has
no `elm/svg` and `elm/time` only as an indirect dependency. The API changes are 4/4 but unapplied;
their `console-api` and `console-spaces` fixtures are the contract. Not measured: the size of the
second entry, the layout cost of a run with 30 steps (assumed to scroll), and the page's first
paint. Target, not a result: one page replaces two console tabs for the two spaces a person uses
daily. The review time saved by the Elm page is a hypothesis.
