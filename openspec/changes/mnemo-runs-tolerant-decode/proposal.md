## Why

On 2026-11-26 the Mnemo page of the `graphos-studio` space showed only
`The answer of /api/runs did not decode: Problem with the value at json.runs[0]: … Expecting an
OBJECT with a field named tokens. The last runs stay below.` and no run at all. The console that
serves the space (pinned `poc-graphos` `d5d7b6e`) does not send `tokens`: that field is task 3.2
of the `console-spaces` change in `poc-graphos`, which has not been implemented. The Studio decoder
(`src/Mnemo/Decode.elm`, `runDecoder`) requires it, and `D.list` fails the whole list on the first
bad entry. On a first load there are no "last runs", so the page is empty. The fixtures under
`tests/Mnemo/fixtures/` were written by hand with `tokens`, so the suite passed while the real
answer failed.

On 2026-11-28 the same field broke the run detail: selecting
`openspec-release-20261127T200702-e1ab` showed `The answer of /api/runs/<run> did not decode:
Problem with the value at json.run: … Expecting an OBJECT with a field named tokens`, and no graph.
`runDetailDecoder` reads `run` with the same `runDecoder`.

The page must work with every console that is pinned today, and one bad run must not hide the
others.

## What Changes

- A run without `tokens` (or without `tokens.card` / `tokens.prompt`) decodes with `0` for the
  missing total and is marked as "tokens not reported", so the row shows `—`, not a false `0`.
- `/api/runs` decodes run by run: a run that does not decode is left out, and the page shows the
  other runs with a notice that says how many runs were skipped and why (the first decode error).
  The answer as a whole fails only when `runs` is missing or is not a list.
- `/api/runs/<run>` decodes a `run` without `tokens` the same way, so the run's graph and board
  are drawn and the totals show `—`.
- `/api/session` decodes the poll interval from `poll_interval`, the key mnemo's console and its
  checked-in fixtures send; `poll` and `poll_seconds` stay accepted. Without it, a console built
  from mnemo `main` (which serves several spaces since `console-spaces`) fails the session read.
- The run fixtures gain a variant taken from the pinned console (no `tokens`, `stopped_by: null`)
  and a variant with a malformed run. The decoder tests cover both.
- The notice text no longer says "the last runs stay below" when no run was ever loaded.

Not in this change: the Mnemo side (`console-spaces` task 3 still adds `tokens` to the answer), a
new layout for the notices (that is `mnemo-workbench-polish`), any route's decoder other than
`/api/runs` and the `run` of `/api/runs/<run>`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `mnemo-workbench`: *The spaces panel switches the console space* reads `poll_interval`;
  *The workflows and runs show status and token use* accepts a run without
  token totals and decodes the list run by run; *The page stays usable when the API fails* names
  a partial decode and stops pointing to runs that were never loaded; *The graph of a run is drawn
  read-only from its route* decodes a `run` detail without token totals.

## Impact

- `src/Mnemo/Decode.elm` (`Run`, `tokensDecoder`, `runsDecoder`), `src/Mnemo/Api.elm` (`getRuns`
  result with skipped entries), `src/Mnemo/App.elm` (notice text, row token cell),
  `src/Mnemo/Format.elm` (unknown token total).
- `tests/Mnemo/DecoderTest.elm`, `tests/Mnemo/AppTest.elm`, `tests/Mnemo/fixtures/` (two new run
  list fixtures, `run-no-tokens.json`, and `session-mnemo.json` copied from mnemo's
  `console-spaces/session.json`).
- No API change and no change in `poc-graphos`. Once `console-spaces` ships `tokens`, the rows show
  the totals with no Studio change.

**Measurement.** Observed on 2026-11-26 in the `graphos-studio` space: the first run of
`/api/runs` (`openspec-release-20261126T140440-c4f3`) has `ended`, `key`, `started`, `status`,
`step_runs`, `stopped_by`, `waiting`, `workflow` and no `tokens`; the page showed no run.
Target: the same answer shows every run, with `—` for the token totals.
