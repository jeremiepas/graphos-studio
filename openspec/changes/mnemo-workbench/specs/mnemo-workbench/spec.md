## Purpose

Give the Studio a read-only Mnemo page: one place to switch between the console's spaces, see each
workflow's runs with their status and token use, and draw the workflow of a run as the graph it is,
without leaving the design system or the tests of this project.

## ADDED Requirements

### Requirement: The page is a second entry of the Studio bundle

The Studio SHALL build `src/Mnemo/Main.elm` to `public/mnemo/mnemo.js` and SHALL ship
`public/mnemo/index.html` that starts it. `mnemo web --frontend-dir public/mnemo` SHALL serve it at
`/studio/`. The graph Studio's entry (`public/index.html` and `studio.js`) MUST stay unchanged and
serve its own page. The page SHALL read `/api/session` before showing data; a `401` SHALL show a
session-expired message and no data, not an empty space.

#### Scenario: The entry is built

- **WHEN** the Studio CI builds the bundle
- **THEN** `public/mnemo/index.html` and `public/mnemo/mnemo.js` exist, and the graph Studio still
  builds `public/studio.js`

#### Scenario: The console serves the page

- **WHEN** `mnemo web --frontend-dir public/mnemo` is opened at its one-time URL
- **THEN** `/studio/` is the Mnemo page and it reads the session

#### Scenario: No session

- **WHEN** `/api/session` answers `401`
- **THEN** the page says the session expired and shows no run list

### Requirement: The spaces panel switches the console space

The page SHALL list the spaces of `/api/session.spaces` in a left panel and SHALL mark the selected
`/api/session.space`. Selecting another space SHALL post `/api/session/space` with the
`X-CSRF-Token` of the session and the JSON body `{"space": "<name>"}`; on success the page SHALL
replace the runs with those of the new space and clear the selected run; on a failure it SHALL keep
the current list and show the error. The page MUST NOT store the selection anywhere but the console
session.

#### Scenario: Switch space

- **WHEN** the session is on `console` and the person selects `graphos-studio`
- **THEN** the page posts the selection and shows the runs of `graphos-studio`

#### Scenario: A refused selection

- **WHEN** the selection answers `404` or `403`
- **THEN** the page keeps the current runs and space, and shows the error

#### Scenario: The session's space

- **WHEN** the page is opened again in the same session
- **THEN** it marks the space the session holds and lists its runs

### Requirement: The workflows and runs show status and token use

The page SHALL group `/api/runs` by each run's `workflow`, with the runs newest first and the
workflows ordered by their newest run. Each run SHALL show its `status`, `started`, `ended`,
`step_runs`, `waiting`, and `tokens.card` and `tokens.prompt`. The page SHALL refresh the list at
the interval `/api/session.poll` names while it is open, and a run that changes status SHALL show
its new status within two intervals. A space with no run SHALL say so; the page MUST NOT show a run
the answer did not hold. A run with no recorded token SHALL show `0` for each total.

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

### Requirement: The graph of a run is drawn read-only from its route

Selecting a run SHALL fetch `/api/runs/<run>/graph` once for that run and `/api/runs/<run>` on
every poll. The page SHALL draw a directed graph in SVG: one node per `nodes` entry, placed by its
`layer` and its order in `nodes`; one line per `edges` entry; an `implied` edge lighter or dashed;
a node's fill and label from the status the run's board holds for the step, with a text label so
status is not colour alone; a legend. A node whose step has a step run SHALL be clickable and SHALL
show that step run's status, attempt and token use, read from `/api/step-runs/<step-run>`; a node
without one SHALL not be clickable. The graph MUST NOT be a canvas, MUST NOT write, and MUST keep
the graph when only a step's status changes. A run whose graph route answers `404` or an error
SHALL show that error in place of the graph.

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

### Requirement: The page stays usable when the API fails

When a read fails, the page SHALL keep the last data it showed, SHALL show a stale or error notice
naming the route, and SHALL offer a retry. A `401` SHALL show the session-expired message. The page
MUST NOT write anything except the space selection, MUST NOT carry a credential, a password or a
model endpoint, and MUST NOT turn a failure into an empty space or an empty run list.

#### Scenario: The API is unreachable

- **WHEN** a poll of `/api/runs` fails
- **THEN** the last groups stay, a notice names `/api/runs`, and a retry is offered

#### Scenario: The session expires

- **WHEN** a read answers `401`
- **THEN** the page says the session expired and keeps the last data behind the message

### Requirement: The page follows the design system and is tested

The page SHALL use the token stylesheet and the components of `Studio.DesignSystem`; no colour
literal SHALL appear outside `Studio.DesignSystem.Tokens.elm`. The spaces panel and the run rows
SHALL be reachable and operable by keyboard, with a visible focus and a text alternative to every
status colour. The suite SHALL test the decoders of `/api/session`, `/api/runs`,
`/api/runs/<run>`, `/api/runs/<run>/graph` and `/api/step-runs/<step-run>` against the fixtures of
the API changes, the grouping and ordering, the token formatting, the graph's pure layout (layers,
x/y, edges, implied) and each state (loading, empty, stale, session expired). `elm-review` and the
CI build of the new entry SHALL pass.

#### Scenario: A colour literal

- **WHEN** a module of `src/Mnemo/` holds a colour literal
- **THEN** the token lint fails

#### Scenario: A changed shape

- **WHEN** a fixture's field is renamed and the decoder is not changed
- **THEN** the decoder test fails

#### Scenario: Keyboard

- **WHEN** the page is driven by keyboard only
- **THEN** a space and a run can be selected, and a node's step run can be opened
