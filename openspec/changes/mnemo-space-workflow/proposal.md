## Why

The Studio page today is three read-only (or soon, one writing) views of the same space: the runs
and their graph (`mnemo-workbench`), the orchestrator's state (`mnemo-orchestrator-view`), and, in
the change `mnemo-decisions`, what waits for a person. It can select a space, but only remembers
that selection in the console session; it cannot save what a person writes about a space, and it
has no single place that puts the orchestrator and the graph of the space together with a way to
act on them.

- **A space says nothing about itself.** The space panel lists and selects the spaces of
  `/api/session.spaces` and posts `POST /api/session/space`; it keeps the choice in the session and
  nothing more. Read on 2026-11-27 in `graphos-studio`, a person left a note that a run needed a
  reminder before it was re-run, and it lived only in their head: the page had no place for it.
- **The orchestrator and the graph are separate.** The orchestrator view shows that a process holds
  the space and what its last heartbeat did; the graph view shows a run's workflow. To have both,
  a person opens the page, reads the two views, and remembers that they are about the same space.
  Measured the same day, the `graphos-studio` space had an orchestrator that held it and one run
  `openspec-release-20261126T221804-28df` that had failed, and the two states were read from two
  parts of the page with no shared frame.
- **There is no single place to act on the space.** A run that failed is resumed or retried; a step
  that waits is approved or answered; the orchestrator is started from the command line (`mnemo
  orchestrate`) or, once this console is rebuilt, from its status route. None of those actions live
  beside the orchestrator and the graph of the space on the page, and the page has no way to re-run
  what it shows.

**The hypothesis, not a result:** a person who, for the selected space, has the orchestrator and
the graph in one place, a note they wrote to the space, and the reruns beside them, acts on the
space sooner and remembers less. What is saved and what is re-run is not measured today; task 1.3
records a baseline before any code.

## What Changes

- **A note the page keeps about the space.** The space panel lets a person write free-text notes
  and tags for the selected space and read them back; the note is stored in the console session and
  is lost at a reload, as the space selection is. The note is not a record: it says nothing about a
  run or a decision, only what a person wrote.
- **A workflow section: the orchestrator and the graph in a sub-list.** For the selected space the
  page gains a section that is a sub-list of two items, `orchestrator` and `graph`. `orchestrator`
  shows what holds the space, its last heartbeat and the state of each run; `graph` draws the
  workflow of a run. The two items are read from the same session and the same poll as the rest of
  the page.
- **A rerun beside what it shows.** The page offers a rerun for each of the three things it can
  show: a run or workflow, the orchestrator, and the orchestrator-plus-graph view. Re-running the
  view re-reads it; re-running the orchestrator asks for a new heartbeat; re-running a run or
  workflow starts the work again. Each rerun goes through the console's session and write header,
  sends no credential, and shows what the console recorded.

Not in this change: the console routes and commands that the reruns need (`mnemo orchestrate` for a
heartbeat, a rerun of a run or workflow, the notes write) are Mnemo's, in `poc-graphos`; the view
is built and tested against fixtures of that contract, and its live check waits for them. The note
is not a field of a run, a workflow or a decision; who a person is (the author of a note is typed,
as everywhere on the page); a schedule of reruns; and removing the separate orchestrator view.

## Capabilities

### New Capabilities

- `mnemo-space-workflow`: the workflow section of the Studio page for the selected space: a note
  the page keeps about the space, and a sub-list of the orchestrator and the graph with a rerun for
  each of the three things it shows.

### Modified Capabilities

- `mnemo-workbench`: the requirement *The page stays usable when the API fails* listed one write,
  the space selection. It now lists the writes of `mnemo-space-workflow` as well: saving a note on
  the space and the reruns of a run, the orchestrator and the view.

## Impact

- **Code**: `src/Mnemo/**` (a module for the workflow section, the note and its reruns; `Api.elm`,
  `Decode.elm` and `App.elm` gain the note, the two items and the reruns), `tests/Mnemo/**`
  (fixtures and tests), `README.md` (the section, the note and what it writes). No new Elm
  dependency is expected; task 2.1 confirms it.
- **Depends on `poc-graphos`** for the routes and commands the reruns use: the notes write on the
  space, a rerun of a run or workflow, and a re-run of the orchestrator's heartbeat, each under
  `/api` with the session and the write header. The section is built and tested against fixtures of
  that contract; its live check waits for the change to be applied and for the Mnemo pin of the dev
  stack to move.
- **Security.** The reruns are the first consequential writes beside the orchestrator and the graph:
  re-running the orchestrator can launch a run, and re-running a run can move it. The page uses the
  console's own origin, session cookie and write header, sends no credential, and never shows a
  rerun as done before the console said so.
- No new store, port or origin. The graph Studio is not changed.
