## Context

See `proposal.md`, Why. What shapes the design:

- **The page that exists.** `src/Mnemo/Main.elm` builds `public/mnemo/mnemo.js`: `Api.elm` (reads
  `/api/session`, `/api/runs`, `/api/runs/<run>`, `/api/runs/<run>/graph`, `/api/step-runs/<step-run>`,
  `/api/orchestrator`, plus the writes `POST /api/session/space`), `Decode.elm`, `App.elm` (the model
  and the messages) and tests against fixtures in `tests/Mnemo/fixtures/`. The page polls at the
  session's interval. Its only write, the space selection, is stored in the console session and lost
  at a reload.
- **What the console serves today**, read on 2026-11-27 in `poc-graphos`
  (`mnemo/src/Mnemo/Infrastructure/Console.hs`): the reads above, the writes `POST /inbox/<step-run>/*`,
  `POST /runs/<run>/{resume,retry,cancel}` and `POST /api/session/space`; no notes write on a space, no
  rerun of a run, no re-run of an orchestrator heartbeat, and no route for the workflow section. Each
  is a Mnemo change in `poc-graphos`; the view is built and tested against fixtures of that contract
  and its live check waits for them.
- **The two views it combines.** `mnemo-orchestrator-view` reads `/api/orchestrator` (the content of
  `mnemo orchestrate status --json`); `mnemo-workbench` draws a run's graph from
  `/api/runs/<run>/graph`. This change puts both in one sub-list for the selected space, with a note
  and a rerun beside them.
- **Rules the page must not weaken.** The design system, the keyboard, a text for every status, the
  stale/error-and-retry notice, and the "never says more than the console said" rule of the
  orchestrator view.

## Goals / Non-Goals

**Goals:**

- For the selected space, the page puts the note, the orchestrator and the graph together in one
  section, with a rerun for each of the three things it shows.
- The note is written and read, and lost at a reload, like the space selection.
- A rerun goes through the console's session and write header, sends no credential, and shows what
  the console recorded.

**Non-Goals:**

- The console routes and commands the reruns need (the notes write, a rerun of a run or workflow, a
  re-run of an orchestrator heartbeat); they are Mnemo's, in `poc-graphos`.
- Who a person is: the author of a note is typed, as everywhere on the page.
- A schedule of reruns; editing a run, a workflow or the note from outside the page.
- Removing the separate orchestrator view; the section reuses its read and its states.

## Decisions

### 1. The section reuses the page's session, poll and writes

The workflow section is a view of `src/Mnemo/Main.elm`, not a third entry. It reads the session once
and reuses the poll, the space selection, the CSRF header and the write model. So a note and a rerun
cost the page nothing it does not already pay, and a failed poll degrades the section with the rest.

| Alternative | Why not |
|---|---|
| A third entry (`public/workflow/`) | A second session, poll and space handling, and no shared session so a `401` on the section is a different message than on the runs. |
| A panel inside the orchestrator view only | What waits in other runs, and the graph, would be a second place; the point is one section for the space. |

### 2. The note lives in the session, typed like a name

The note and its tags are a field of the model, typed once while the space is selected and gone at a
reload. It is not a record of a run or a decision; it carries no author. So it can be saved and read
through the space-selection write without an identity, and it cannot outlive the session.

| Alternative | Why not |
|---|---|
| Kept in the browser's storage | `mnemo-workbench` stores nothing outside the session; a note kept in a shared browser would be read by the next person. |
| A field of a run or a decision | The note says nothing about a run; it would wrongly attach to something it is about. |

### 3. The reruns are shown because the console offers them

The section maps the reruns the console says it can do to controls and ignores the rest. So a rerun
that the console does not yet serve is hidden, and a rerun shown is never one the console refuses. The
console is the judge of a rerun, as it is of a decision; the page never marks a rerun done before the
console records it.

| Alternative | Why not |
|---|---|
| The page decides which reruns apply, from its view | It would repeat the console's rules and offer a rerun the console refuses. |
| Every rerun always shown | Re-running the orchestrator needs a heartbeat; re-running a run needs the run; the view cannot tell which the console allows. |

### 4. The section is drawn from the two reads it needs

The section reads `/api/orchestrator` and `/api/runs/<run>/graph` at the session's interval, with the
runs. The note is read and written through the space route's body. The graph item draws only the
selected run's graph; the other runs are listed by the orchestrator view's words, not by the graph.

| Alternative | Why not |
|---|---|
| One read that returns orchestrator and graph together | The console serves them on separate routes; a combined route would add a read the console does not have today. |
| Re-draw the whole graph for every run | Only the selected run is graphed; the others are words, as the orchestrator view already lists them. |

### 5. A rerun is never optimistic

The model keeps, per rerun, one of: waiting, sending, recorded (with what the console said), refused
(with the console's decision), failed (no answer). The control is disabled while sending; the view
changes only when the answer arrives.

| Alternative | Why not |
|---|---|
| Mark the rerun done at the click, undo on failure | Re-running the orchestrator can launch a run. Showing "done" for a second and then "the console refused it" is the confusion this section must not create. |

### 6. The reruns need console commands that do not exist yet

Re-running a run or workflow, and re-running an orchestrator heartbeat, are console commands the
console does not serve today. The design assumes their names and write shapes when the fixtures are
written, and task 6.1 replaces each assumption with its contract. Until then the control is hidden and
the section shows only the view's rerun, which the console has.

| Alternative | Why not |
|---|---|
| Wait for the console commands before proposing | `mnemo-workbench` and `mnemo-orchestrator-view` were built the same way, against fixtures of unapplied changes; the wait would only move the work. |

## Risks / Trade-offs

- **[A rerun command is never added to Mnemo]** → The control is never shown. The view's rerun stays.
- **[The notes write shape differs from the fixture]** → The assumption is replaced by the contract in
  task 6.1, and the live check waits.
- **[Re-running the orchestrator launches an unexpected run]** → The page asks nothing of the person
  a rerun does not; it sends one write per click, shows no confirmation, and the console's own rule
  holds.
- **[A note that is never shown]** → The note is a field of the model only while the space is
  selected; at a reload it is gone, as the selection is, and the page says the space has no note.

## Migration Plan

The section is additive. It is merged with its tests; the Mnemo pin of the dev stack moves when the
console's notes and rerun routes are applied in `poc-graphos`, and the live check runs then. Until
then the built page meets a console without them and hides the note and the reruns that need them,
showing only the view's rerun. Rollback is a revert of the merge: the page writes nothing the console
does not record itself.

## Open Questions

- Should the rerun of a run be a fresh start, or resume from the last attempt? Fixed by the console
  command's contract, which task 6.1 records.
- Should a note survive a space being deleted? Left out; the note lives in the session, which the
  console ends with the space.
