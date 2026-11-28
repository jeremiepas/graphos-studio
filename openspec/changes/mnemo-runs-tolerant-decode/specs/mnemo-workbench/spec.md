## MODIFIED Requirements

### Requirement: The spaces panel switches the console space

The page SHALL list the spaces of `/api/session.spaces` in a left panel and SHALL mark the selected
`/api/session.space`. Selecting another space SHALL post `/api/session/space` with the
`X-CSRF-Token` of the session and the JSON body `{"space": "<name>"}`; on success the page SHALL
replace the runs with those of the new space and clear the selected run; on a failure it SHALL keep
the current list and show the error. The page MUST NOT store the selection anywhere but the console
session. The page SHALL read the poll interval of `/api/session` from `poll_interval`, `poll` or
`poll_seconds`, so the session as mnemo's console sends it (its `console-api` and `console-spaces`
fixtures name `poll_interval`) decodes.

#### Scenario: Switch space

- **WHEN** the session is on `console` and the person selects `graphos-studio`
- **THEN** the page posts the selection and shows the runs of `graphos-studio`

#### Scenario: A refused selection

- **WHEN** the selection answers `404` or `403`
- **THEN** the page keeps the current runs and space, and shows the error

#### Scenario: The session's space

- **WHEN** the page is opened again in the same session
- **THEN** it marks the space the session holds and lists its runs

#### Scenario: The session of mnemo's console

- **WHEN** `/api/session` answers `csrf`, `digest`, `poll_interval`, `space` and `spaces`, as
  mnemo's `console-spaces/session.json` fixture does
- **THEN** the page lists both spaces, marks the selected one, and polls at `poll_interval` seconds

### Requirement: The workflows and runs show status and token use

The page SHALL group `/api/runs` by each run's `workflow`, with the runs newest first and the
workflows ordered by their newest run. Each run SHALL show its `status`, `started`, `ended`,
`step_runs`, `waiting`, and `tokens.card` and `tokens.prompt`. The page SHALL refresh the list at
the interval `/api/session.poll` names while it is open, and a run that changes status SHALL show
its new status within two intervals. A space with no run SHALL say so; the page MUST NOT show a run
the answer did not hold. A run with no recorded token SHALL show `0` for each total. A run whose
answer has no `tokens` object, or a `tokens` object without `card` or `prompt`, SHALL be shown with
`—` for each missing total, and SHALL NOT fail the list. The page SHALL decode `/api/runs` run by
run: a run that does not decode SHALL be left out, the other runs SHALL be shown, and a notice
SHALL say how many runs were left out and give the first decode error. The answer SHALL fail as a
whole only when `runs` is missing or is not a list.

#### Scenario: Two workflows

- **WHEN** the runs hold two workflows with one run each
- **THEN** the page shows two groups, each with its run's status, times, counts and token totals

#### Scenario: A run in progress

- **WHEN** a run's status changes from `running` to `passed` while the page is open
- **THEN** the group shows `passed` within two poll intervals

#### Scenario: An empty space

- **WHEN** the selected space has no run
- **THEN** the page says the space has no run and shows no group

#### Scenario: No token recorded

- **WHEN** a run's step runs recorded no card or prompt token
- **THEN** the run shows `0` card and `0` prompt tokens

#### Scenario: A console without token totals

- **WHEN** `/api/runs` answers runs with `key`, `workflow`, `status`, `started`, `ended`,
  `step_runs`, `waiting` and `stopped_by`, and no `tokens`
- **THEN** the page shows every run with its status, times and counts, and `—` for the card and
  prompt totals, and shows no decode notice

#### Scenario: One malformed run

- **WHEN** `/api/runs` answers three runs and the second has no `status`
- **THEN** the page shows the first and the third run, and a notice says that one run was left out
  and names the missing `status` field

#### Scenario: Not a run list

- **WHEN** `/api/runs` answers an object without `runs`
- **THEN** the read fails, the notice names `/api/runs` and offers a retry, and the runs shown
  before stay

### Requirement: The graph of a run is drawn read-only from its route

Selecting a run SHALL fetch `/api/runs/<run>/graph` once for that run and `/api/runs/<run>` on
every poll. The page SHALL draw a directed graph in SVG: one node per `nodes` entry, placed by its
`layer` and its order in `nodes`; one line per `edges` entry; an `implied` edge lighter or dashed;
a node's fill and label from the status the run's board holds for the step, with a text label so
status is not colour alone; a legend. A node whose step has a step run SHALL be clickable and SHALL
show that step run's status, attempt and token use, read from `/api/step-runs/<step-run>`; a node
without one SHALL not be clickable. The graph MUST NOT be a canvas, MUST NOT write, and MUST keep
the graph when only a step's status changes. A run whose graph route answers `404` or an error
SHALL show that error in place of the graph. The `run` of `/api/runs/<run>` SHALL decode with the
same rules as a run of `/api/runs`: a `run` without `tokens`, or with `tokens` lacking `card` or
`prompt`, SHALL decode, the graph SHALL be drawn, and each missing total SHALL be shown as `—`.

#### Scenario: A branch and a join

- **WHEN** the graph holds `a` on layer 0, `b` and `c` on layer 1 and `d` on layer 2, with the
  edges `a→b`, `a→c`, `b→d`, `c→d`
- **THEN** the page draws four nodes in three layers and four lines

#### Scenario: An implied edge

- **WHEN** an edge is marked `implied`
- **THEN** the page draws it dashed or lighter than a declared edge, and the legend says so

#### Scenario: A step's status

- **WHEN** the run's board shows a step `passed` and another `failed`
- **THEN** their nodes carry the two statuses' colours and text labels

#### Scenario: A node's step run

- **WHEN** a node's step has a step run and the person clicks the node
- **THEN** the page shows that step run's status, attempt and card and prompt tokens

#### Scenario: A fan-out step

- **WHEN** a node is marked as a fan-out
- **THEN** the graph keeps one node for the step and shows that it fans out

#### Scenario: A run detail without token totals

- **WHEN** `/api/runs/<run>` answers a `run` with `key`, `workflow`, `status`, `started`, `ended`,
  `step_runs`, `waiting` and `stopped_by`, and no `tokens`
- **THEN** the page draws the run's graph with the statuses of its board, shows `—` for the card
  and prompt totals, and shows no decode notice

### Requirement: The page stays usable when the API fails

When a read fails, the page SHALL keep the last data it showed, SHALL show a stale or error notice
naming the route, and SHALL offer a retry. A `401` SHALL show the session-expired message. The page
MUST NOT write anything except the space selection, MUST NOT carry a credential, a password or a
model endpoint, and MUST NOT turn a failure into an empty space or an empty run list. A notice
SHALL say that earlier data is kept only when the page holds earlier data; on a first read that
fails, the notice SHALL say that no run could be loaded.

#### Scenario: The API is unreachable

- **WHEN** a poll of `/api/runs` fails
- **THEN** the last groups stay, a notice names `/api/runs`, and a retry is offered

#### Scenario: The session expires

- **WHEN** a read answers `401`
- **THEN** the page says the session expired and keeps the last data behind the message

#### Scenario: The first read fails

- **WHEN** the first read of `/api/runs` fails and no run was shown before
- **THEN** the notice names `/api/runs`, says no run could be loaded, offers a retry, and does not
  say that earlier runs stay below
