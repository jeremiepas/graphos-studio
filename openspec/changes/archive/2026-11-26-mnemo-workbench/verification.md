# Verification

Date: 2026-11-26. Branch: `openspec/mnemo-workbench`.

The console API changes `mnemo-console-in-studio` and `console-spaces` are
proposed and 4/4 in `poc-graphos` but not applied to the pinned console
(`dev-stack/pins.json`, `d5d7b6e`). The page is therefore built and tested
against the contract fixtures; the live check on the two spaces
(`graphos-studio`, `console`) is the step that remains after those changes are
applied and the pin moves.

## Gates

Command: `devenv tasks run studio:ci`

Result: exit 0. The task builds `public/studio.js` and
`public/mnemo/mnemo.js`, runs `elm-test`, `elm-review`, the fixture drift
check, the Mnemo entry check and the token lint.

Command: `elm-test`

Result:

```
TEST RUN PASSED
Duration: 251 ms
Passed:   140
Failed:   0
```

The 140 tests include the 36 new `Mnemo.*` tests: the five decoders and a
renamed field, the grouping and ordering, the token formatting, the graph
layout (layers, positions, branch/join, implied edges), the status-to-token
mapping, the session and selection update, and the loading, empty, stale,
session-expired and keyboard-reachable views.

Command: `elm-review`

Result: `I found no errors!`

Command: `.scripts/fixture-drift-check.sh`

Result: `OK` for the graph fixture and for the five Mnemo fixtures.

Command: `.scripts/mnemo-entry-check.sh`

Result: `OK: public/mnemo/index.html starts Elm.Mnemo.Main on #app`.

Token lint (no hex literal outside `Studio.DesignSystem.Tokens.elm`): no
violations.

Command: `openspec validate mnemo-workbench --strict`

Result: `Change 'mnemo-workbench' is valid`.

## Live check

Not done: it needs `mnemo web --frontend-dir public/mnemo` from the two API
changes. Until then the page runs on the Studio's own server at `/mnemo/` (see
the README), which exercises the same API paths against fixtures only through
the tests, not against a console.
