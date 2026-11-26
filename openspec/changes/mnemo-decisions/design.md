## Context

See `proposal.md`, Why. What shapes the design:

- **The page that exists.** The Mnemo page is one Elm entry (`src/Mnemo/Main.elm`, built to
  `public/mnemo/`), with `Api.elm` (reads, and one write: the space selection, with the session's
  `X-CSRF-Token`), `Decode.elm`, `App.elm` (the model and the messages), and tests against five
  fixtures in `tests/Mnemo/fixtures/`. It polls at the interval the session names. The review of
  its run reported 140 passing tests at commit `e743f4c` (not measured again here).
- **What the console writes today**, read on 2026-11-26 in `poc-graphos`
  (`mnemo/src/Mnemo/Infrastructure/Console.hs:520-558`): `POST /inbox/<step-run>/approve`,
  `POST /inbox/<step-run>/answer`, `POST /runs/<run>/resume`, `POST /runs/<run>/retry` (form fields
  `by`, `step`, `note`) and `POST /runs/<run>/cancel`. Each needs the session and the write
  header. Today they answer with a redirect or a plain text.
- **What the contract adds**, in `console-api` of `mnemo-console-in-studio` (`poc-graphos`, 1 of 16
  tasks done on 2026-11-26): `/api/inbox` (what waits, a question with its text and its answer
  schema), a JSON answer for each write that keeps its path and its status (`200` with what was
  recorded; `401`, `403`, `409` with the decision that won and its author), and fixture files
  under `mnemo/test/fixtures/console-api/`, which do not exist yet.
- **What an attention entry holds** (`Console.hs`, the attention page): a kind, the workflow, the
  run and step, a line that says what happened, an explanation, the last lines of an output, since
  when, a reason, and the actions that apply.
- **What Mnemo does not have:** a way to ask for changes at a waiting approval. An approval is
  approved, or its run is cancelled. Retry grants an attempt to a failed step only.
- **Rules of the human inbox that the page must not weaken** (`human-inbox` in `poc-graphos`): one
  decision per waiting attempt, the first wins and a stale page gets `409`; an answer is validated
  by the console (`422`); a name is required; writes go through the harness's use cases.

## Goals / Non-Goals

**Goals:**

- A person reads what waits and decides without leaving the page where the runs are.
- The page never says more than the console said: no action is shown as done before the answer,
  and no answer is judged valid by the page.
- The turn that asks for another solution works today for a failed step, and appears for a
  waiting approval the day the console offers it, with no new release of the page.

**Non-Goals:**

- Any change of Mnemo: its API, its use cases, the rule of who may decide.
- Cancelling a run from the page.
- A notification outside the page (a sound, a system notification, a message).
- An identity: the name is typed, as in the console and on the command line.
- Editing a proposal or a file from the page. A turn carries a note; the workflow writes the next
  proposal.
- The other kinds of attention entry: an abandoned run, the delivery entries.

## Decisions

### 1. A view of the Mnemo entry, not a third entry

The decisions view is a view of `src/Mnemo/Main.elm`, next to the runs: the same session, the same
poll, the same space selection, and links both ways between a run and its item.

| Alternative | Why not |
|---|---|
| A third entry (`public/decisions/`) | A second copy of the session and space handling, and no way to go from a waiting node of the graph to its item without a page load. |
| A panel inside the run view only | What waits in other runs would be invisible; the point is one list for the space. |

### 2. Two reads: the inbox for what waits, the attention list for what failed

`/api/inbox` gives the waiting approvals and questions with the question and its schema.
`/api/attention` gives the failed steps and the resumable runs, with the actions that apply. The
view shows the inbox items first, then the attention entries that offer `retry` or `resume`, and
leaves the other kinds out.

| Alternative | Why not |
|---|---|
| The attention list alone | It names a waiting step and its actions, and the contract gives the answer schema on the inbox route only. |
| Derive what waits from `/api/runs` and each run | N requests per poll, and a second place that decides what "waits" means. |
| Show every attention entry | An abandoned run and a delivery entry need actions this change does not offer (cancel, the delivery commands); listing them with no action would look like a broken page. |

### 3. An action is shown because the console offers it

An item carries the actions the console says apply. The view maps the ones it knows (approve,
answer, resume, retry, ask for changes) to controls and ignores the others. So the turn at a
waiting approval is in this change, tested against a fixture, and invisible until Mnemo offers it.

| Alternative | Why not |
|---|---|
| Decide in the page which actions an item has, from its kind and status | The page would repeat the rules of the attention model, and would offer an action the console refuses. |
| Leave the turn at an approval to a later change of the Studio | It is what was asked for, and the view is the same list, form and write as a retry with a note. Only its fixture is provisional. |
| Build the turn from what exists: cancel the run and start another | The run, its worktree and its pull request would be lost for one remark. |

The name of that action and the shape of its write are fixed by the Mnemo change that adds it.
Until that change exists, this design assumes: the action is named `revise` in the item's actions,
and its write takes a name and a note, as `retry` does. Task 9.1 replaces the assumption with the
contract.

### 4. The form is drawn from the schema; the console is the judge

A pure function turns an answer schema into a form description (enumeration, boolean, string,
number, required), and another turns the form's state into the JSON answer. Anything else falls
back to one JSON text. The page sends what it built and shows the verdict: `422` with the
console's message.

| Alternative | Why not |
|---|---|
| A JSON text for every question | It is what the Haskell console has for most shapes, and it hides the options, which is the first thing asked for. |
| Validate the answer in the page before sending | A second validator would disagree with the console some day, and the console validates anyway. |
| A JSON-schema form library | The schemas of Mnemo are a small subset (its `Schema.hs`); the four field kinds above cover the questions the workflows of this space ask, and the fallback covers the rest. |

### 5. A write is never optimistic

The model keeps, per item, one of: waiting, sending, decided (with what the console recorded),
refused (with the console's decision or message), failed (no answer). The view changes only when
the answer arrives. The action is disabled while sending.

| Alternative | Why not |
|---|---|
| Mark the item decided at the click, undo on failure | An approval can let a workflow merge. Showing "approved" for a second and then "someone else decided" is the one confusion this view must not create. |
| Refresh the whole inbox after each write instead of reading the answer | The answer already says what was recorded; the next poll confirms it. |

### 6. The name lives in the page

The name is a field of the model: typed once, used for every decision while the page is open, gone
at a reload.

| Alternative | Why not |
|---|---|
| Keep it in the browser's storage | `mnemo-workbench` stores nothing outside the console session; a name kept in a shared browser would sign the next person's approval. |
| Take it from the session | The console's session has no person; adding one is an identity, a non-goal. |

### 7. The earlier turns come from the run

The step runs of a run (`/api/runs/<run>`, already polled for the selected run) hold each attempt
of a step. The view shows, under an item, the attempts of its step in order with the note and the
author of the turn that asked for each. It fetches the run of an item when the item is opened, not
for every item at every poll.

| Alternative | Why not |
|---|---|
| A history route per step | The contract has a history of decisions for the space; a step's attempts are already on its run. |
| Keep the turns in the page | They would be lost at a reload and unknown to a second person. |

### 8. The fixtures are the contract, and say when they are provisional

The decoders are tested against files in `tests/Mnemo/fixtures/`: the inbox, the attention list,
and the answer of each write for each status. They are copied from
`mnemo/test/fixtures/console-api/` when Mnemo emits them. Before that they are written here from
the text of the contract, in a folder named `provisional/`, and a new step of `studio:ci` prints the
name of every file in it, so nobody takes a hand-written shape for a measured one. (The existing
fixture-drift check compares the graph fixture with its Elm copy and is not changed.)

| Alternative | Why not |
|---|---|
| Wait for the API before proposing the view | `mnemo-workbench` was built the same way, against fixtures of unapplied changes; the wait would only move the work. |
| Fixtures written here with no mark | A decoder that passes its test and fails on the real console is the cost of that. |

### 9. One poll, one more request

The inbox and the attention list are read at the session's interval, with the runs. An answer
whose `digest` did not change replaces nothing, so an open form is not redrawn under the person's
hands.

| Alternative | Why not |
|---|---|
| Poll only when the view is open | The number of waiting decisions must be right on the runs view too. |
| Push from the console | The console has no push; the poll interval is two seconds. |

## Risks / Trade-offs

- [The API change is never applied] → Groups 1 to 8 are built and tested on fixtures; group 10
  (the live check) says it is blocked. The page hides the view when `/api/inbox` answers `404`,
  and says that the console does not serve decisions yet.
- [The real shapes differ from the provisional fixtures] → The provisional folder is printed by
  the CI, and task 10.1 replaces every file before the live check and checks that it is empty.
- [The turn at an approval is never added to Mnemo] → The control is never shown. The retry with a
  note for a failed step still gives a turn.
- [An approval made by mistake] → The page asks for a name and sends one write per click; it adds
  no confirmation dialog, because the console has none and a second click protects nobody who
  clicks fast. The decision shows its author, and Mnemo's history keeps it.
- [Two people decide at once] → The console's first-wins rule; the page shows the `409` with the
  winner.
- [A form that cannot express an answer] → The JSON fallback is always reachable from the form.
- [A long output or note breaks the layout] → Texts are shown as the console cut them; the view
  wraps and scrolls, and adds no cut of its own.

## Migration Plan

The view is additive. It is merged with its tests; the Mnemo pin of the dev stack moves when
`mnemo-console-in-studio` is applied in `poc-graphos`, and the live check of group 10 runs then.
Until then the built page meets a console without `/api/inbox` and hides the view. Rollback is a
revert of the merge: the page writes nothing the console does not record itself.

## Open Questions

- Should an item show a link to what the gate is about (the pull request of a release run)? The
  gate's text is shown; a link needs the workflow to put one in its output.
- Should the view also be the place to cancel a run? Left out here; it is the most destructive
  write of the console.
