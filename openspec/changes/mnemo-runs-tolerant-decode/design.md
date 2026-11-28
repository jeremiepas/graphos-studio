## Context

See proposal.md, *Why*. `runDecoder` is a `D.map8` with `D.field "tokens" tokensDecoder`;
`runsDecoder` is `D.field "runs" (D.list runDecoder)`. `Api.expectJson` turns any decode error into
`BadBody`, and `App.update` (`GotRuns (Err err)`) keeps `model.runs` and sets a notice that always
ends with "The last runs stay below." `Grouping.groupRuns` and the row view read `run.tokens.card`
and `run.tokens.prompt` as `Int`.

## Goals / Non-Goals

**Goals:** the page works with the pinned console (no `tokens`) and with the console after
`console-spaces` (with `tokens`); one bad run never hides the others; the fixtures include an
answer as the pinned console really sends it.

`/api/runs/<run>` decodes its `run` through the same `runDecoder`, so decision 1 fixes it too; it
gets its own fixture and test so it cannot regress apart from the list.

**Non-Goals:** lenient decoding of the routes other than `/api/runs` and `/api/runs/<run>`; a new notice component (the polish change);
changing the API.

## Decisions

1. **`tokens : Maybe Tokens`, with each total `Maybe Int`.** A missing total is not a zero: the
   spec already says a run with no recorded token shows `0`, and that is a different fact from "the
   console did not report it". The row shows `—` for `Nothing`.
   *Rejected:* `D.oneOf [ field, succeed {0,0} ]`. Simpler, but it shows a false `0` and the
   difference between "no token" and "not reported" is lost.
2. **Decode the list as `List D.Value`, then each value on its own.** `runsDecoder` becomes
   `D.field "runs" (D.list D.value)` followed by a pure `decodeRuns : List D.Value -> { runs :
   List Run, skipped : Int, firstError : Maybe String }`. It is pure, so it is tested without HTTP.
   *Rejected:* `D.oneOf [ D.map Just runDecoder, D.succeed Nothing ]` per item. It drops bad runs
   but loses the error text, so the notice could not say why.
3. **The partial result is a success with a notice, not an `Err`.** `getRuns` answers
   `Result Error RunList`; `GotRuns (Ok list)` replaces the runs and sets the notice when
   `skipped > 0`. A partial answer is newer than the last data, so it replaces it.
4. **Fixtures from the real answer.** `runs-no-tokens.json` holds the shape seen on 2026-11-26
   (keys and values anonymised to fixture values); `runs-malformed.json` has one run without
   `status`. The existing `runs.json` stays as the `console-spaces` shape. `run-no-tokens.json` is
   `run.json` with its `run` in the pinned console's shape (no `tokens`, `stopped_by: null`).

5. **`poll_interval` joins the session decoder's `D.oneOf`.** mnemo's `console-api` and
   `console-spaces` fixtures, which mnemo's suite regenerates, are the contract and name
   `poll_interval`; the Studio's hand-written `session.json` says `poll`. The fixture
   `session-mnemo.json` is copied byte for byte from mnemo's so the test follows the real shape.
   *Rejected:* changing mnemo to send `poll`. The console's own frontend and its fixtures already
   use `poll_interval`, and the Studio is the side that drifted.

## Risks / Trade-offs

- [A silently skipped run hides a real problem] → the notice counts the skipped runs and shows the
  first error; nothing is skipped without a notice.
- [`Maybe` totals ripple into grouping and formatting] → `Format.tokens : Maybe Int -> String` is
  the one place that renders `—`; workflow totals in the polish change sum only the `Just` values.

## Migration Plan

None. The decoder accepts both shapes; no pin changes.
