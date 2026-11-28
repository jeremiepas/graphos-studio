## 1. Fixtures and failing tests

- [ ] 1.1 Add `tests/Mnemo/fixtures/runs-no-tokens.json` (two runs in the pinned console's shape:
  no `tokens`, `stopped_by: null`) and `runs-malformed.json` (three runs, the second without
  `status`). Also add `run-no-tokens.json`: `run.json` whose `run` has no
  `tokens` and `stopped_by: null`. Verify: the three files are valid JSON (`jq . file`).
- [ ] 1.2 In `tests/Mnemo/DecoderTest.elm`, add the tests of the scenarios *A console without token
  totals*, *One malformed run*, *Not a run list* and *A run detail without token totals*
  (`runDetailDecoder` on `run-no-tokens.json`), and keep the `runs.json` test. Verify:
  `elm-test` fails on the new tests only.

- [ ] 1.3 Add `tests/Mnemo/fixtures/session-mnemo.json`, a copy of mnemo's
  `mnemo/test/fixtures/console-spaces/session.json`, and a `DecoderTest` case *The session of
  mnemo's console* (two spaces, poll `2`). Verify: it fails before 2.4.

## 2. Decoder

- [ ] 2.1 Change `Run.tokens` to `Maybe Tokens` with `card` and `prompt` as `Maybe Int`;
  `tokensDecoder` reads each field with `D.maybe`. Verify: the *no tokens* and *run detail without token totals* tests pass.
- [ ] 2.2 Change `runsDecoder` to `D.field "runs" (D.list D.value)` and add the pure `decodeRuns`
  returning the runs, the skipped count and the first error. Verify: the *malformed* and *not a list*
  tests pass.
- [ ] 2.3 Update `Api.getRuns` to answer the run list record. Verify: `elm make src/Mnemo/Main.elm`
  compiles.
- [ ] 2.4 Add `D.field "poll_interval" D.int` to the poll `D.oneOf` of `sessionDecoder`. Verify:
  the *session of mnemo's console* test passes.

## 3. Page

- [ ] 3.1 Render a missing total as `—` in the run row and the step-run panel (one formatter in
  `Format.elm`). Verify: a `FormatTest` case for `Nothing` and `Just 0`.
- [ ] 3.2 `GotRuns (Ok list)` sets a notice when `skipped > 0` ("1 run left out: <error>").
  Verify: an `AppTest` case for the malformed fixture shows two rows and the notice.
- [ ] 3.3 Say "The last runs stay below." only when `model.runs` is not empty, and "No run could be
  loaded." otherwise, for `401` and other errors. Verify: `AppTest` cases for a first-read failure
  and a later failure.

## 4. Gates

- [ ] 4.1 Run `elm-test`, `elm-review`, both `elm make --optimize` builds and the token lint.
  Verify: all pass.
- [ ] 4.2 Start `devenv up` against the pinned console and open the Mnemo page in the
  `graphos-studio` space. Verify: the runs are listed with `—` totals and there is no decode notice;
  selecting a run draws its graph with no `/api/runs/<run>` decode notice.
