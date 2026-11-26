## Why

The Mnemo page of the Studio shows what the runs are doing. It cannot say what they wait for, and
it cannot let a person decide.

- **The page is read-only.** `mnemo-workbench` lists the runs with their status, their token use
  and the graph of a run, and its specification says the page "MUST NOT write anything except the
  space selection". A run that waits for a person shows a `waiting` count and nothing more.
- **A decision is made somewhere else.** A person approves or answers in the Haskell console
  (`/inbox`, one space per page) or on the command line (`mnemo approve`, `mnemo answer`), then
  resumes the run with another command. Measured on 2026-11-26 in the `graphos-studio` space: the
  run `openspec-release-20261126T142915-2a54` had two human gates, approved at 14:33:37 and
  15:44:41 UTC, both from outside the Studio.
- **A gate has one answer.** A waiting approval can be approved; nothing lets a person say "not
  this, do it another way" and get a new proposal to approve. Read on 2026-11-26 in `poc-graphos`,
  the writes of the console are approve, answer, resume, retry and cancel
  (`mnemo/src/Mnemo/Infrastructure/Console.hs:520-558`); retry grants one more attempt with a note,
  for a step that failed only.
- **The contract for the page exists, the routes do not yet.** `console-api`, in the change
  `mnemo-console-in-studio` of `poc-graphos`, specifies `/api/inbox` (what waits, with its question
  and its answer schema) and a JSON answer for every write. It is not applied: the console of
  `poc-graphos` serves `/api/runs`, `/api/runs/<run>` and `/api/attention` under `/api` today
  (`Console.hs:276-278`).

**The hypothesis, not a result:** a person who sees what waits, with its options, on the page
where the runs are, decides sooner and resumes the run without a second tool. The time a step
waits is not measured today; task 1.3 records a baseline before any code.

## What Changes

- **A decisions view in the Mnemo page.** The page shows how many decisions wait in the selected
  space, and lists them oldest first: the workflow, the run, the step, the kind (an approval or a
  question), the text of the gate and since when it waits. It also lists the steps that failed
  their last attempt and the runs that only need to be resumed.
- **The options of a question.** The answer schema of a question is drawn as a form: one choice
  per value of an enumeration, yes or no for a boolean, a field for a text or a number, and a JSON
  text for any other shape. The console stays the judge of an answer.
- **Decide on the page.** A person gives their name and approves, or answers. The page shows what
  the console recorded: the decision with its author and time, or the refusal (another decision
  won, the answer does not fit the schema, the session expired). A decided item stays listed,
  marked with who decided and when.
- **Resume from the page.** After a decision, the run is offered a resume, as in the console.
- **A turn: ask for another solution.** For a step that failed, a person grants one more attempt
  with a note saying what to do differently. For a waiting approval, a person asks for changes
  with a note instead of approving, when the console offers that action; the new proposal comes
  back to the list as a new attempt, with the earlier turns shown, and can then be approved.
- **The runs lead to the decision.** A waiting run in the list, and a waiting step in the graph,
  open the item that waits.
- The page keeps its rules: the design system, the keyboard, a text for every status, and the
  last data kept when a read fails.

Not in this change: the API (it is Mnemo's, in `poc-graphos`); the use case that lets a person ask
for changes at a waiting approval (a change to propose in `poc-graphos`; this page shows the
action only when the console offers it); cancelling a run; abandoned runs and the delivery entries
of the attention list; notifications; who a person is (the name is typed, as in the console);
remote access; removing the Haskell inbox page.

## Capabilities

### New Capabilities

- `mnemo-decisions`: the decisions view of the Mnemo page: what waits for a person, the options of
  a question, the approval and the answer, the resume, and the turn that asks for another
  solution.

### Modified Capabilities

- `mnemo-workbench`: the requirement *The page stays usable when the API fails* allowed one write,
  the space selection. It now allows the writes of `mnemo-decisions` as well.

## Impact

- **Code**: `src/Mnemo/**` (new modules for the decisions view and the answer form; `Api.elm`,
  `Decode.elm` and `App.elm` gain the inbox, the attention list and the writes),
  `tests/Mnemo/**` (fixtures and tests), `README.md` (the view and what it writes). No new Elm
  dependency is expected; task 2.1 confirms it.
- **Depends on `mnemo-console-in-studio`** in `poc-graphos` for `/api/inbox` and the JSON answers
  of the writes. The view is built and tested against fixtures of that contract; its live check
  waits for the change to be applied and for the Mnemo pin of the dev stack to move.
- **Depends, for the turn at a waiting approval, on a Mnemo change that is not proposed yet.**
  Everything else works without it; that part of the view stays hidden until the console offers
  the action.
- **Security.** These are the first writes of consequence from the Studio: an approval can let a
  workflow merge. The page uses the console's own origin, session cookie and write header, sends
  no credential, and never shows an action as done before the console said so.
- No new store, port or origin. The graph Studio is not changed.
