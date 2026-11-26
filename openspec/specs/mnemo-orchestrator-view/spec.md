# mnemo-orchestrator-view Specification

## Purpose
Show, on the Mnemo page of the Studio, whether an orchestrator moves the runs of the selected
space, what its last heartbeat did, and for each run that is not final the one word and the reason
that say whether it will move, without giving the page any control over the orchestrator.

## Requirements

### Requirement: The view says whether an orchestrator holds the space

The Mnemo page SHALL have an orchestrator view for the selected space, read from the console's
orchestrator route under `/api`. It SHALL say, as the console reports it, that an orchestrator
holds the space or that none does, with a text and not by colour alone. The page SHALL show that
state wherever the view is not open, and SHALL refresh it at the interval `/api/session.poll`
names. The page MUST NOT decide by itself that an orchestrator is live or gone: the age of the
last heartbeat is shown as an age and changes no state. A space no orchestrator ever held SHALL
say so and SHALL show no heartbeat.

#### Scenario: Live

- **WHEN** the console reports that an orchestrator holds the space
- **THEN** the view says that an orchestrator holds the space, and the page shows that state on
  the runs view too

#### Scenario: Gone

- **WHEN** the console reports that no orchestrator holds the space and that the last heartbeat
  was an hour ago
- **THEN** the view says that no orchestrator holds the space and shows the time of that heartbeat

#### Scenario: An old heartbeat of a live orchestrator

- **WHEN** the console reports that an orchestrator holds the space and its last heartbeat is ten
  minutes old
- **THEN** the view still says that an orchestrator holds the space, and shows the heartbeat as
  ten minutes old

#### Scenario: Never held

- **WHEN** the console reports no orchestrator and no heartbeat for the space
- **THEN** the view says that no orchestrator has run on this space and shows no heartbeat

#### Scenario: Another space

- **WHEN** the person selects another space
- **THEN** the view shows the state of that space and nothing of the first

### Requirement: The last heartbeat is shown

The view SHALL show the time and the sequence number of the last heartbeat, what it did as the
console counts it, the causes the orchestrator acts on, and its cap of runs when the console gives
one. A cause the orchestrator does not act on SHALL NOT be shown as acted on. The view SHALL show
these values as given and MUST NOT compute a count of its own.

#### Scenario: A heartbeat that launched one run

- **WHEN** the last heartbeat has the number 42 and launched one run, and the causes are `decided`
  and `granted`
- **THEN** the view shows the number 42, its time, one launch, and the two causes

#### Scenario: Two heartbeats, nothing to do

- **WHEN** a poll brings a heartbeat whose number is one more and whose counts are zero
- **THEN** the view shows the new number and time, and that nothing was launched

### Requirement: Every run that is not final has one word and its reason

The view SHALL list every run the console's orchestrator route gives, each with its workflow, its
status and its word with the reason: `held` (a process works on it), `moves` (the cause for which
the next heartbeat launches it), `later` (why, and when it is due when the console says when),
`waits` (the step that waits for a person), `failed` (the step that failed and its reason),
`remediation` (its launches did not take, or its endpoint stays unreachable) and `off` (why
nothing moves it). Each word SHALL have a text label and a short explanation reachable from the
list. A word the page does not know SHALL be shown as the console gave it, with its reason, and
MUST NOT hide the run. A run in `remediation` whose entry names the file of its launches' output
SHALL show that path as a text that can be copied; the page MUST NOT try to read the file. Each
run SHALL offer a link that selects it in the runs view. A space with no such run SHALL say that
no run is left to move.

#### Scenario: Three runs, three words

- **WHEN** one run waits for an answer nobody gave, one failed a step without a grant, and one has
  three launches that did not take
- **THEN** their lines say `waits` with the step, `failed` with the step and its reason, and
  `remediation` with the launches and the path of the output file

#### Scenario: A run that moves

- **WHEN** a run is decided and the orchestrator acts on `decided`
- **THEN** its line says `moves` with the cause `decided`

#### Scenario: A run that is due later

- **WHEN** a run's back-off has not passed and the console says when it is due
- **THEN** its line says `later` with that time

#### Scenario: No orchestrator

- **WHEN** no orchestrator holds the space and a run is decided
- **THEN** its line says `off` with the reason the console gives

#### Scenario: A word the page does not know

- **WHEN** the console gives a run the word `queued`, which the page has no label for
- **THEN** the run is listed with `queued` and its reason as given

#### Scenario: Nothing to move

- **WHEN** every run of the space is final
- **THEN** the view says that no run is left to move

#### Scenario: From a line to its run

- **WHEN** the person follows the link of a line
- **THEN** the run is selected in the runs view and its graph is drawn

### Requirement: The run list carries the word of each run

In the run list of the page, a run that the orchestrator route gives a word SHALL show that word
next to its status, with its reason available from the row. A run the route does not list, a final
run among them, SHALL show no word. When the route is not served or its read failed, the run list
SHALL show its runs as before, with no word.

#### Scenario: A waiting run that will move

- **WHEN** the run list shows a run `waiting` and the route gives it `moves`
- **THEN** the row shows `waiting` and `moves`

#### Scenario: A passed run

- **WHEN** a run is `passed`
- **THEN** its row shows no word

#### Scenario: The route is not served

- **WHEN** the orchestrator route answers `404`
- **THEN** the run list shows every run with its status and no word

### Requirement: The view reads and never controls

The view MUST NOT write: it offers no control that starts or stops an orchestrator, asks for a
heartbeat, launches, resumes or queues a run, or changes a cause or the cap. When the console does
not serve the orchestrator route (`404`), the view SHALL say that this console does not serve the
orchestrator's state and SHALL show no state, no heartbeat and no word. When a read of the route
fails otherwise, the view SHALL keep the last state it showed, mark it stale with the time it was
read, name the route and offer a retry. A `401` SHALL show the session-expired message of the
page.

#### Scenario: No request but a read

- **WHEN** the view is used for a whole session
- **THEN** every request it caused is a `GET`

#### Scenario: A console without the route

- **WHEN** the orchestrator route answers `404`
- **THEN** the view says that the console does not serve the orchestrator's state, and does not
  say that no orchestrator holds the space

#### Scenario: A failed poll

- **WHEN** a poll of the route gets no answer after a state was shown
- **THEN** the last state stays, marked stale with its time, the route is named and a retry is
  offered

### Requirement: The view follows the design system and is tested

The view SHALL use the token stylesheet and the components of `Studio.DesignSystem`, with no
colour literal outside `Studio.DesignSystem.Tokens.elm`. The state, every line and every link
SHALL be reachable by keyboard with a visible focus, and every word and state SHALL have a text.
The suite SHALL test: the decoder of the orchestrator route against fixtures of a live
orchestrator, of none, of a space never held, and of a list that holds each of the seven words and
one unknown word; the explanation of each word; the word of a run in the run list; and each state
of the view (loading, live, gone, never held, not served, stale, session expired). `elm-review`
and the CI build of the Mnemo entry SHALL pass.

#### Scenario: A changed shape

- **WHEN** a field of the fixture is renamed and the decoder is not changed
- **THEN** the decoder test fails

#### Scenario: Keyboard

- **WHEN** the view is driven by keyboard only
- **THEN** the state can be read, a line reached and its run opened

#### Scenario: A colour literal

- **WHEN** a module of the view holds a colour literal
- **THEN** the token lint fails
