## Context

See `proposal.md`, Why. What shapes the design:

- **The page that exists.** One Elm entry (`src/Mnemo/Main.elm`), with the session, the spaces
  panel, the run list grouped by workflow, the graph of a run, a poll at the interval the session
  names, and the rule that a failed read keeps the last data with a notice.
- **What Mnemo says about its orchestrator**, read on 2026-11-26 in `poc-graphos` (its
  `mnemo/README.md` and the specification `orchestrator` of the change `mnemo-orchestrator`):
  - `mnemo orchestrate` repeats a heartbeat in the foreground and holds a lock of its space;
    `--once` does one heartbeat.
  - One orchestrator node per space is updated in place at each heartbeat with its time, its
    sequence number, its counts and the causes the process acts on. There is no list of past
    heartbeats.
  - `mnemo orchestrate status [--json]` says whether an orchestrator holds the space, "from the
    lock and not from a time", names the last heartbeat and the causes, and gives each run that is
    not final exactly one word with its reason: `held`, `moves`, `later`, `waits`, `failed`,
    `remediation`, `off`. A run the orchestrator launched names the file of its output,
    `$XDG_STATE_HOME/mnemo/orchestrator/<space>/<run>.log`. It writes nothing. Its exit code is 0
    with an orchestrator, 1 without.
  - More words may come: a later slice of that change adds a queue.
- **What is not there.** No `/api` route for the orchestrator, in the console or in any change.
  The command is on `main` of `poc-graphos` and not in the source the dev stack pins (`d5d7b6e`):
  measured on 2026-11-26, the build of the `graphos-studio` wrapper answers
  "Invalid argument `status'".
- **The exact JSON of the command was not read** for this proposal. Task 1.2 records it from a
  build of `main`, and the fixtures are that output.

## Goals / Non-Goals

**Goals:**

- A person sees at a glance whether the space is being moved, and for each run why it is or is
  not.
- The page repeats what Mnemo says and adds no judgement: no liveness guessed from a time, no
  count of its own, no word of its own.
- The page keeps working with a console that does not serve the route, and with a Mnemo that adds
  a word.

**Non-Goals:**

- Any control: start, stop, heartbeat now, launch, resume, queue, configure.
- The route in Mnemo, and its name.
- A history of heartbeats, a chart, an uptime figure.
- The content of a launch's output file.
- A link from a `waits` line to the item that waits: it belongs with `mnemo-decisions`.

## Decisions

### 1. A view of the Mnemo entry, and one line of state on every view

The orchestrator view is a view of `src/Mnemo/Main.elm`. The state (an orchestrator holds the
space, none does, not served) is also one line of the page's header, so it is seen from the runs.

| Alternative | Why not |
|---|---|
| Only a line in the header | The word and the reason of each run need a list; the header has no room for it. |
| A separate entry | A second session and space selection for a view whose lines link to the runs. |

### 2. One route with the content of the status command

The view reads one route that answers what `mnemo orchestrate status --json` prints for the
selected space, as one JSON object with a `digest` like the other routes of `console-api`. Until
the Mnemo change names it, this design assumes the path `/api/orchestrator`; task 1.3 replaces the
assumption.

| Alternative | Why not |
|---|---|
| Compute the words in the page from `/api/runs` and `/api/attention` | The words come from a rule proved in Mnemo's Lean model (held, decided, granted, back-off, cap, launches). A second copy in Elm would drift, and the page cannot see a lock. |
| Add the word to `/api/runs` only | The state of the orchestrator and its heartbeat are not a property of a run. The run list gets its word from the same read (decision 5). |
| Run the command from the Studio's dev stack and serve its output as a file | It would work on one machine, outside the session and the space selection of the console. |

### 3. Liveness is what the console says

The view shows "an orchestrator holds the space" or "none does" from the field the console gives,
which Mnemo reads from the lock. The age of the last heartbeat is shown as an age, in plain words,
and never changes the state or its colour.

| Alternative | Why not |
|---|---|
| Call it gone after N missed intervals | Mnemo says the opposite on purpose: a heartbeat can be long, a store can be away for two heartbeats, and the lock is the truth. Two answers to "is it running" on one machine is the confusion to avoid. |
| Hide the age | An orchestrator that holds the space and has not completed a heartbeat for ten minutes is worth seeing; the person judges. |

### 4. Seven known words, and any other shown as given

The page has a label and one sentence of explanation for each of the seven words. A word it does
not know is shown as text with its reason, in the neutral style, and its run stays listed.

| Alternative | Why not |
|---|---|
| A closed type that fails to decode an unknown word | The whole view would go blank the day Mnemo adds a word, which its next slice does. |
| No explanation, the word alone | `later`, `off` and `remediation` do not say what a person should do. The sentences are those of Mnemo's README, shortened. |

### 5. The run list reads the same answer

The word of a run in the run list comes from the same read, matched by the run's key. No second
request, and a run the route does not list has no word.

| Alternative | Why not |
|---|---|
| A request per run | N requests per poll for a value one answer holds. |
| No word in the run list | The run list is where a person looks first; "why does this run not move" should be answered there. |

### 6. Three states that must not be confused

"Not served" (`404`: the console has no such route), "no orchestrator" (the console answered that
none holds the space) and "stale" (a read failed after one succeeded) are three states of the
model with three texts. A `404` never becomes "no orchestrator holds the space".

| Alternative | Why not |
|---|---|
| Treat `404` as an error like any other | Until the Mnemo change is merged and the pin moves, `404` is the normal answer; a permanent error banner on the page would teach people to ignore banners. |
| Hide the view entirely on `404` | A person who expects the view would not know why it is missing. One line says it. |

### 7. The fixtures are real output of the command

Task 1.2 builds Mnemo from `main` of `poc-graphos`, prepares a space and records
`mnemo orchestrate status --json` in the cases the tests need. Those files are the fixtures. Only
what the route adds around them (the `digest`) is assumed, and marked so.

| Alternative | Why not |
|---|---|
| Write the fixtures by hand from the README | The JSON was not read for this proposal; a hand-written shape would be a guess presented as a contract. |
| Wait for the route | The content exists today in a command; only its transport is missing. |

## Risks / Trade-offs

- [The route is never added to Mnemo] → The view says "not served" and the rest of the page is
  unchanged. The cost is the view's code, tested on real command output.
- [The route's shape differs from the command's] → Task 8.1 replaces the fixtures by the route's
  own and records each difference.
- [The command's JSON is poorer than the text output] (for example no due time for `later`) → Task
  1.2 records it; a field the JSON does not hold is not shown, and the spec's "when the console
  says when" already allows it.
- [A person reads "no orchestrator" as an error] → It is a state, shown neutrally: many spaces
  have none. The view says how one is started, as a command to copy, and starts nothing.
- [The path of an output file is of no use in a browser] → It is a text to copy into a terminal.
  Reading the file from the page would make the console serve files, a non-goal.
- [The word in the run list crowds the row] → The word is short; its reason is on demand.

## Migration Plan

The view is additive and read-only. Merged before the route exists, it shows "not served". When
the Mnemo change is merged and the dev stack's pin moves, the live check of group 8 runs. Rollback
is a revert of the merge.

## Open Questions

- Should the header's line of state be shown for a space that never had an orchestrator, or only
  once one has run? It changes one text.
