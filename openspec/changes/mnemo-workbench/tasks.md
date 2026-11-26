# Tasks

Each group writes its checks before its code. Every build and test runs through `devenv shell`.
The fixtures come from the contract of `console-api` and `console-spaces` in `poc-graphos`; the
page is checked live after those two changes are applied. The graph Studio is not changed.

## 1. The fixtures and the decoders

- [ ] 1.1 Checks first: one decoder test per route's fixture — `/api/session` (the spaces, the
  selected space, the poll, the CSRF token), `/api/runs` (the run's workflow, status, times,
  counts and `tokens.card`/`tokens.prompt`), `/api/runs/<run>` (the board and its step runs),
  `/api/runs/<run>/graph` (nodes, layers, edges, implied) and `/api/step-runs/<step-run>` (the
  status, attempt and card/prompt tokens) — and a test that a renamed field fails the decoder.
- [ ] 1.2 Copy the five fixtures of the two API changes into `tests/Mnemo/fixtures/` (from their
  emitted files when they exist; from the contract before), and make 1.1 pass.

## 2. The second entry and its build

- [ ] 2.1 Checks first: `elm make src/Mnemo/Main.elm --output=public/mnemo/mnemo.js` in a test
  task, and a test that `public/mnemo/index.html` starts `Elm.Mnemo` on the `app` node (a shell
  check or a small fixture test).
- [ ] 2.2 Add `src/Mnemo/Main.elm` (`Browser.element`, the model, the messages, the update and the
  view skeleton, the tokens' stylesheet), `public/mnemo/index.html`, the `elm/svg` dependency and
  the direct `elm/time`; add `mnemo:build` to `devenv.nix`; make 2.1 pass.

## 3. The session and the spaces panel

- [ ] 3.1 Checks first on the update: the session decoder fills the spaces, the selected space and
  the poll; a selection's success replaces the space and clears the run; a `403`/`404` keeps the
  list and sets the error; the left panel marks the selected space.
- [ ] 3.2 Add the session fetch, the spaces panel, the `POST /api/session/space` command with the
  `X-CSRF-Token` header and the `{"space": "<name>"}` body, and the error state; make 3.1 pass.

## 4. The workflows, the runs and the token use

- [ ] 4.1 Checks first on pure functions: the grouping by `workflow` with the newest run first and
  the groups by their newest run; the token formatting (`1.2k`, and the exact value); a run with no
  token is `0`; an empty list gives no group.
- [ ] 4.2 Add the `/api/runs` fetch, the poll with `Time.every` at the session's interval, the
  workflow/run view with status, times, counts and the two token totals, and the empty and stale
  states; make 4.1 pass.

## 5. The run graph

- [ ] 5.1 Checks first on the pure layout: the layers and positions of a chain, a branch and a
  join, a single node and an implied edge; the status-to-token mapping (passed, failed, running,
  waiting, pending, skipped) and its text label.
- [ ] 5.2 Add the selected run's `/api/runs/<run>/graph` fetch once per run, the `/api/runs/<run>`
  poll, the SVG view with the nodes, the edges (implied dashed), the legend, and the node click
  that fetches `/api/step-runs/<step-run>` and shows its status, attempt and tokens; make 5.1 pass.

## 6. The states and the design system

- [ ] 6.1 Checks first: the loading, empty, stale and session-expired views; a `401` and a failed
  read keep the last data; the keyboard reaches a space, a run and a node's step run.
- [ ] 6.2 Make 6.1 pass with the tokens' stylesheet, the components, a visible focus and a text
  label beside every status colour; the token lint stays green (no hex outside `Tokens.elm`).

## 7. The gates and the documentation

- [ ] 7.1 Add `mnemo:build` to `studio:ci` and to `.github/workflows/studio.yml`; run `elm-review`
  over `src/Mnemo/`; make the new entry part of the build and test gates.
- [ ] 7.2 Document the page in the README (the entry, the flag, the routes it reads) and, when
  `dev-stack/scripts/mnemo.sh` is in `main`, add `--frontend-dir public/mnemo` to the console
  process; the page is checked on 8090 before that.

## 8. Verify

- [ ] 8.1 Run `devenv tasks run studio:ci` and `openspec validate mnemo-workbench --strict`;
  record the outputs and, after the API changes are applied, the date the page was checked live
  on the two spaces (`graphos-studio`, `console`) in `verification.md`.
