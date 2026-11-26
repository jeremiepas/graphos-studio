## Context

Facts read on 2026-11-26:

- `graphos-studio` has one Elm entry, `src/Main.elm` (the graph workbench), built to
  `public/studio.js`; `public/index.html` loads it and `public/ports.js`. `Studio.DesignSystem`
  holds the tokens (including `success`, `danger`, `warning`, `accent`, `textMuted`, `canvasEdge`)
  and the generated stylesheet; the CI lints hex literals outside `Tokens.elm` (`devenv.nix`,
  `README.md`).
- `src/Main.elm` is a `Browser.application` with graph-specific model and ports; the studio's
  104 elm-tests and `elm-review` run in `studio:ci`. `elm.json` has `elm/http`, `elm/json`,
  `elm/url`, `elm/time` (indirect) and no `elm/svg`.
- The API changes in `poc-graphos`: `mnemo-console-in-studio` (4/4, unapplied) gives `/api/session`,
  `/api/runs`, `/api/runs/<run>`, `/api/step-runs/<step-run>`, `/api/runs/<run>/graph` and
  `--frontend-dir`; `console-spaces` (4/4, unapplied) adds `spaces` and the selected space to
  `/api/session`, `POST /api/session/space`, and `tokens.card`/`tokens.prompt` to `/api/runs`. The
  fixtures under `mnemo/test/fixtures/console-api/` and `console-spaces/` are the contract.
- The run graph route (the base's decision 8) holds `nodes` (id, executor, layer, foreach) and
  `edges` (from, to, implied), no status; the statuses come from `/api/runs/<run>`.
- The two spaces to show are `graphos-studio` and `console` (the user's configuration).

## Goals / Non-Goals

**Goals:** a second entry that is the console's page; a spaces panel over the session; the
workflow/run list with status and token use; a read-only SVG graph of a run; the design system's
tokens and tests; a build and CI that carry the entry.

**Non-Goals:** the attention, inbox, run, step-run and delivery pages; a Haskell page; an editor of
workflows; writes other than the space selection; pan and zoom; deep links to a run; the API.

## Decisions

### 1. A second Elm entry, not a mode of the graph workbench

`src/Mnemo/Main.elm` is a `Browser.element` with its own model and no ports; the build emits
`public/mnemo/mnemo.js`; `public/mnemo/index.html` starts it. The graph workbench keeps
`src/Main.elm`, `public/index.html` and `public/studio.js`.

**Why:** the graph workbench's model is built around the graph, its ports and its navigation; a
Mnemo mode would couple two unrelated states and double the refactor. A second entry also keeps the
console's page free of the renderer and local storage. **Alternatives:** a tab in `Main.elm`:
rejected for the coupling and the larger diff; a separate repository: rejected because it would
duplicate the design system, the toolchain and the CI.

### 2. `public/mnemo/` is the directory the console serves

The console's `--frontend-dir` points at `public/mnemo/`, whose `index.html` is the Mnemo page;
the graph workbench stays at the Studio's own 8090 and `public/index.html`. The tokens' stylesheet
is inserted by the page's view, as `Main.elm` does.

**Why:** the one-time console URL lands on `/studio/`, which must be the console's page, not the
graph workbench; the graph workbench is a separate tool with its own origin and bundle. **Alternatives:**
put a tab in `public/index.html`: rejected because the console's landing would be the graph
workbench; serve the page at `/studio/mnemo.html`: rejected because the one-time URL would still
land on the graph workbench; a redirect: rejected as an extra hop and a second entry to maintain.

### 3. SVG for the run graph

The graph is `Svg` nodes and lines inside the page, placed by layer and by the index in `nodes`.
Nodes use `success`/`danger`/`warning`/`accent`/`textMuted` from the tokens, a text label and a
title; an `implied` edge uses `canvasEdge` with a dash; the legend is HTML.

**Why:** the nodes are DOM: the token lint covers them, the keyboard and the tests reach them, and
a pure layout function can be checked without a renderer. **Alternatives:** the `vis-network` the
graph workbench vendors: rejected because it draws on a canvas, outside the tokens, the keyboard
and `elm-test`; absolutely positioned HTML nodes with SVG lines: rejected as more code for the same
result.

### 4. The runs are grouped in the page

`/api/runs` already holds each run's `workflow`; the page groups by it, newest run first and the
groups by their newest run. No workflow route is added.

**Why:** the grouping is presentation; the run is the unit a person acts on. **Alternatives:** an
`/api/workflows` route: rejected as a second shape and a second fixture for no new value; a
workflow list built from the definitions: rejected because the console holds runs, not a catalogue.

### 5. The space selection is the session's

The page reads `spaces` and `space` from `/api/session`, posts `/api/session/space` with the
`X-CSRF-Token` and `{"space": "<name>"}`, and takes the answer as the new session. It stores no
selection; a reload reads the session.

**Why:** the API change selected a session-level space so the base's routes keep their paths; the
page mirrors it and cannot drift. **Alternatives:** a `?space=` on every request: rejected because
one omission reads the wrong space; local storage: rejected because the console session already
holds the selection and the person expects it to be the same in a second tab.

### 6. Poll the runs and the selected run; fetch the graph once per run

`Time.every` uses `/api/session.poll`; each tick fetches `/api/runs`, and when a run is selected,
`/api/runs/<run>`; the graph is fetched when the selected run changes and cached for that run.

**Why:** the graph route is immutable for a run (the base's decision 8), while the run's board
changes; polling both lists keeps the page current without re-fetching the graph. **Alternatives:**
poll the graph: rejected as waste; no poll: rejected because the user wants a run in progress to
update.

### 7. The API fixtures are the decoders' input

The suite copies the `/api/session`, `/api/runs`, `/api/runs/<run>`, `/api/runs/<run>/graph` and
`/api/step-runs/<step-run>` files of `console-api` and `console-spaces` into
`tests/Mnemo/fixtures/`, decodes each, and fails when a field is renamed. The live page is checked
against the running console after the API changes are applied.

**Why:** the two repositories already share a fixture contract (the graph contract is the
precedent); a shape change fails on both sides. **Alternatives:** hand-written shapes: rejected as
drift; a mock server in the Studio: rejected as more code than the files.

### 8. The token use is the run list's card and prompt totals

The page shows `tokens.card` and `tokens.prompt` from `/api/runs`, formatted with a compact suffix
(`1.2k`) and the exact value in a title; it fetches no per-run detail to build the list.

**Why:** the API change puts the sums where the list polls; a per-run fetch would be N+1. The
request size (the trace) stays on the step page. **Alternatives:** fetch each run's detail: rejected
for the cost; a separate usage route: rejected as another shape.

### 9. The page is built and served in the same gates

`devenv.nix` gains `mnemo:build` (`elm make src/Mnemo/Main.elm --optimize --output=public/mnemo/mnemo.js`)
and `studio:ci` runs it after `studio:build`; the CI workflow mirrors it. `elm.json` gains `elm/svg`
and moves `elm/time` to direct. The dev-stack's `mnemo.sh` gains `--frontend-dir public/mnemo` when
the dev-stack change is in `main`; until then the page runs on the Studio's own server at `/mnemo/`.

**Why:** a second bundle that CI does not build rots; the dev stack is the live check. **Alternatives:**
build it by hand: rejected as a hidden step; one bundle for both pages: rejected by decision 1.

## Risks / Trade-offs

- **The API changes are unapplied** → the page is built and tested against the fixtures first; the
  live check waits for `mnemo-console-in-studio` and `console-spaces`. The proposal, design and
  tests do not pretend the routes exist.
- **A stale fixture** → the decoder test fails; the fixture is copied from the API change, not
  invented.
- **The second entry and CI** → `studio:ci` builds both; the token lint covers `src/Mnemo/`; a
  missing build fails the gate.
- **A wide graph** (assumed: a 30-step workflow) → the SVG scrolls in both directions; pan and zoom
  are a follow-up, not a first-slice requirement.
- **The dev-stack `mnemo.sh` is in another change** → the page is served on 8090 until that change
  is in `main`; the console's flag is the live path.
- **The session expires** → the page says so and keeps the last data; the person reopens the
  one-time URL.
- **The status colours are tokens** → `success`, `danger`, `warning`, `accent` and `textMuted`
  already exist; no new token is needed. A text label accompanies every colour.

## Migration Plan

1. Build the entry and the page against the copied fixtures (groups 1-4); the graph Studio is
   untouched.
2. Add the entry to `studio:ci` and the CI workflow; the dev stack serves it at `/mnemo/` for the
   manual check.
3. When `mnemo-console-in-studio` and `console-spaces` are applied, add the flag
   `--frontend-dir public/mnemo` to the dev-stack `mnemo.sh` and check the page on the console
   origin (the base's task 3.2/3.3 records the check).

Rollback: remove the entry and its build task; the graph Studio is unchanged.

## Open Questions

- Pan and zoom for a graph that does not fit: a follow-up; the first slice scrolls.
- Deep links to a run: a follow-up; the first slice is one page with the selected run in its model.
- A full step-run page from a node: the base's later workbench pages; the first slice shows the
  status, attempt and token use from `/api/step-runs/<step-run>`.
