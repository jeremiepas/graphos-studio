## Why

The Mnemo page shows the runs of a space. It does not show whether anything is moving them.

- **A run that should move looks like a run that waits.** Mnemo has an orchestrator: a heartbeat
  that resumes the runs that need no decision (`mnemo orchestrate`). On the page, a run that was
  approved a minute ago and a run nobody looks at both show `waiting`. Nothing says whether an
  orchestrator holds the space, when it last looked, or why a run was left alone.
- **The answer exists on the command line only.** `mnemo orchestrate status [--json]` says whether
  an orchestrator holds the space, names its last heartbeat and the causes it acts on, and gives
  every run that is not final one word with its reason: `held`, `moves`, `later`, `waits`,
  `failed`, `remediation` or `off` (`mnemo/README.md` of `poc-graphos`, on its `main`).
- **This repository cannot run that command yet.** Measured on 2026-11-26: the Mnemo build the
  `graphos-studio` wrapper uses answers "Invalid argument `status'", and the source the dev stack
  pins (`d5d7b6e`) has no such command; it came to `main` of `poc-graphos` after that pin.
- **No route serves it.** The orchestrator change of `poc-graphos` leaves "a console page" to the
  Studio, and no change specifies an `/api` route for the orchestrator. The console serves
  `/api/runs`, `/api/runs/<run>` and `/api/attention` today.
- **This space already has an orchestrator configured.** `~/.config/mnemo/graphos-studio.yaml`
  holds an `orchestrator` section (`max_runs: 1`, `resume: [decided, granted]`).

**The hypothesis, not a result:** a person who sees on the page that no orchestrator holds the
space, or why a run is left alone, acts sooner than a person who finds out from a run that never
moved. Nothing is measured; the change records a baseline before any code.

## What Changes

- **An orchestrator view in the Mnemo page.** For the selected space it says whether an
  orchestrator holds the space, as the console reports it from the lock; the time and the number
  of its last heartbeat, what that heartbeat did, the causes it acts on and its cap of runs. A
  space no orchestrator ever held says so.
- **One word per run, with its reason.** Every run that is not final is listed with its status and
  the word Mnemo gives it: held by a process, moved at the next heartbeat and for which cause,
  later and when it is due, waiting for which step, failed at which step, in remediation, or off.
- **The word in the run list.** Each run of the run list carries its word, so the reason a run
  does not move is visible without opening another view.
- **What a person must fix is not buried.** A run in remediation shows that its launches did not
  take and the path of the file that holds their output, as a text to copy.
- **Read-only.** The view starts, stops and configures nothing, and launches no run.
- **A page that stays honest.** The view never decides by itself that an orchestrator is gone
  because its heartbeat is old; when the console does not serve the route it says so and shows
  nothing else; a failed read keeps the last state with a notice.

Not in this change: the route itself (it is Mnemo's, to be specified in `poc-graphos`); starting
or stopping an orchestrator; a heartbeat on demand; changing the causes or the cap; queueing a run
from the page; a history or a chart of heartbeats (Mnemo keeps the last one only); reading the
output file of a launch.

## Capabilities

### New Capabilities

- `mnemo-orchestrator-view`: the orchestrator view of the Mnemo page: who holds the space, the
  last heartbeat, the word and the reason of every run that is not final.

### Modified Capabilities

None. The view only reads, so the rule of `mnemo-workbench` that the page writes nothing but the
space selection holds unchanged.

## Impact

- **Code**: `src/Mnemo/**` (a module for the view; `Api.elm`, `Decode.elm` and `App.elm` gain one
  read), `tests/Mnemo/**` (fixtures and tests), `README.md`.
- **Depends on a route that does not exist.** The view needs the console to serve the state of the
  orchestrator under `/api`, with the content of `mnemo orchestrate status --json`. That route is
  a change to propose in `poc-graphos`; until it is served, the built page hides the view.
- **Depends on a newer Mnemo pin.** The dev stack pins a Mnemo that predates the orchestrator's
  loop and status; the live check waits for the pin to move.
- **Independent of `mnemo-decisions`** (pull request #4). Either can be merged first. When both
  are in, a run whose word is `waits` could link to the item that waits; that link is left to
  whichever lands second.
- No write, no new store, port, origin or credential. The graph Studio is not changed.
