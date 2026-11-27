## Purpose

Let a person see, on the Mnemo page of the Studio, everything that waits for them in a space, with
the options each item offers, and decide there: approve, answer, resume, or ask for another
solution and approve the next one.

## ADDED Requirements

### Requirement: The decisions view lists what waits for a person

The Mnemo page SHALL have a decisions view for the selected space. It SHALL list every item of
`/api/inbox` that waits, oldest first, with its workflow, its run, its step, its attempt, its kind
(an approval or a question), the text of the gate or of the question, and since when it waits. It
SHALL list after them the entries of `/api/attention` that offer a retry or a resume, with the
line that says what happened and, for a failed step, its reason and the last lines of its output.
The page SHALL show, wherever the view is not open, the number of items that wait, and SHALL
refresh the list and the number at the interval `/api/session.poll` names. A space where nothing
waits SHALL say so. The view MUST NOT show an item the answers did not hold, and MUST show the
texts as the console gave them: it adds no secret and removes no redaction.

#### Scenario: One approval and one question

- **WHEN** `/api/inbox` holds a waiting approval of two hours and a waiting question of ten
  minutes
- **THEN** the view lists the approval first, then the question with its text, and the page shows
  that two decisions wait

#### Scenario: A failed step

- **WHEN** `/api/attention` holds a step that failed its last attempt and offers `retry`
- **THEN** the view lists it with its reason and the last lines of its output

#### Scenario: Nothing waits

- **WHEN** the inbox is empty and no attention entry offers a retry or a resume
- **THEN** the view says that nothing waits for a person, and the page shows no number

#### Scenario: A new item arrives

- **WHEN** a run reaches a human gate while the page is open
- **THEN** the item is listed and the number grows within two poll intervals

#### Scenario: Another space

- **WHEN** the person selects another space
- **THEN** the view shows the items of that space and none of the first

### Requirement: A question shows its options

For a question, the view SHALL draw a form from the answer schema: one choice per value of a
field that is an enumeration; yes and no for a boolean field; a text field for a string; a number
field for a number or an integer; and the name of each field with a mark when it is required. A
schema, or a field, of any other shape SHALL be shown as one JSON text to edit, with the schema
next to it. The form SHALL build the answer as JSON from what the person chose. The page MUST NOT
decide that an answer is valid: it sends it, and the console's verdict is what it shows.

#### Scenario: A choice among three

- **WHEN** the schema has one required field `direction` that is an enumeration of three values
- **THEN** the form shows three choices, and choosing the second builds the answer
  `{"direction": "<second value>"}`

#### Scenario: A text and a yes or no

- **WHEN** the schema has a string field `note` and a boolean field `ship`
- **THEN** the form shows a text field and a yes or no choice, and builds an object with both

#### Scenario: A shape the form does not draw

- **WHEN** the schema has a field that is a list of objects
- **THEN** the form shows one JSON text to edit and the schema, and sends what the person typed

#### Scenario: An approval has no form

- **WHEN** the item is an approval
- **THEN** the view shows the text of the gate and the approve action, and no answer form

### Requirement: A person decides from the page

An approval and an answer SHALL require the person's name, and SHALL be posted to the console's
own write route for that item with the session's `X-CSRF-Token` and `Accept: application/json`.
The page SHALL show an item as decided only after the console answered `200`, with the author and
the time the console recorded. On `409` it SHALL show the decision that won and its author, and
SHALL NOT offer the action again. On `422` it SHALL show the console's message next to the form
and keep what the person typed. On `401` it SHALL show the session-expired message; on `403` or
any other failure it SHALL show the error, keep the item as it was and offer to try again. While a
write is in flight the action SHALL be disabled, so one click sends one write. A decided item
SHALL stay in the view, marked with who decided and when. The name SHALL be kept while the page is
open and MUST NOT be stored anywhere else.

#### Scenario: Approve

- **WHEN** a person types their name and approves a waiting approval, and the console answers
  `200`
- **THEN** the item is marked approved with that name and the console's time, and the number of
  waiting decisions drops by one

#### Scenario: Answer a question

- **WHEN** a person chooses an option of a question and sends it, and the console answers `200`
- **THEN** the item is marked answered with the answer, the name and the time

#### Scenario: No name

- **WHEN** the name is empty
- **THEN** the approve and send actions are disabled and nothing is posted

#### Scenario: Someone else decided first

- **WHEN** the console answers `409` with the decision another person recorded
- **THEN** the item shows that decision and its author, and offers no action

#### Scenario: An answer that does not fit

- **WHEN** the console answers `422`
- **THEN** the console's message is shown next to the form, the typed answer is kept, and the
  item still waits

#### Scenario: Two clicks

- **WHEN** a person clicks approve twice before the console answered
- **THEN** one write is posted

#### Scenario: The write fails

- **WHEN** the write gets no answer
- **THEN** the item is unchanged, an error names the route, and the action can be tried again

### Requirement: A decided run can be resumed from the page

When an item is decided and its run waits for no other decision, and for every attention entry
that offers a resume, the view SHALL offer to resume the run, and SHALL post the console's resume
write for that run. After `200` the view SHALL show the run as resumed and the run list SHALL show
its new status within two poll intervals. A refusal SHALL be shown with the console's message: a
run that another process holds is not resumed twice.

#### Scenario: Resume after an approval

- **WHEN** the only waiting step of a run is approved and the person chooses resume
- **THEN** the resume is posted, and the run shows `running` or a later status within two poll
  intervals

#### Scenario: Another step still waits

- **WHEN** a run has two waiting steps and one is decided
- **THEN** no resume is offered for that run until the other is decided

#### Scenario: The run is already held

- **WHEN** the console refuses the resume because a process holds the run
- **THEN** the view shows the console's message and offers no second resume

### Requirement: A person can ask for another solution

For a step that failed its last attempt and whose entry offers `retry`, the view SHALL let a
person grant one more attempt with their name and a note that says what to do differently, and
SHALL post the console's retry write for that run and step. For a waiting approval, the view SHALL
offer to ask for changes, with a name and a note that is required, only when the item names that
action among the actions the console offers; it MUST NOT show that action, and MUST NOT post it,
for an item that does not offer it. After the console recorded the turn, the item SHALL show that
a new attempt was asked, by whom and with which note. When the step waits again, the view SHALL
list it as a new attempt and SHALL show under it the earlier turns of that step in order: each
attempt, the note that asked for it and its author. The new attempt is decided as any item.

#### Scenario: One more attempt for a failed step

- **WHEN** a person gives their name and the note "use the existing decoder" on a failed step, and
  the console answers `200`
- **THEN** the retry is posted with the step, the name and the note, and the entry shows that an
  attempt was granted

#### Scenario: A retry the console refuses

- **WHEN** the console answers `409` to a retry
- **THEN** the view shows the console's reason and the entry is unchanged

#### Scenario: Ask for changes at an approval

- **WHEN** a waiting approval offers the action to ask for changes, and a person sends their name
  and the note "split the page in two"
- **THEN** the turn is posted, the item shows that a new attempt was asked with that note, and it
  no longer offers approve for the old attempt

#### Scenario: The console does not offer the turn

- **WHEN** a waiting approval does not name that action
- **THEN** the view shows approve only

#### Scenario: The next proposal is approved

- **WHEN** the step waits again as attempt 2 after a turn
- **THEN** the view lists attempt 2 with the note and the author of the turn under it, and a
  person can approve it

#### Scenario: A turn without a note

- **WHEN** a person asks for changes with an empty note
- **THEN** the action is disabled and nothing is posted

### Requirement: The runs lead to the decision

A run of the run list that waits for a person SHALL offer a link that opens the decisions view on
its items. In the graph of a run, a node whose step waits for a person SHALL be marked as waiting,
with a text and not by colour alone, and selecting it SHALL open its item. An item of the view
SHALL offer a link that opens its run and the graph of that run.

#### Scenario: From the run list

- **WHEN** a run shows one waiting step and the person follows its link
- **THEN** the decisions view opens with that item in view

#### Scenario: From the graph

- **WHEN** the graph of a run has a node whose step waits for an approval
- **THEN** the node is marked as waiting, and selecting it opens the approval

#### Scenario: From an item to its run

- **WHEN** the person follows the run link of an item
- **THEN** the run is selected and its graph is drawn

### Requirement: The view follows the design system and is tested

The view SHALL use the token stylesheet and the components of `Studio.DesignSystem`, with no
colour literal outside `Studio.DesignSystem.Tokens.elm`. Every item, form field and action SHALL
be reachable and operable by keyboard, with a visible focus and a label; an error SHALL be
announced next to the control it concerns. The suite SHALL test: the decoders of `/api/inbox`,
`/api/attention` and of the answer of each write against fixtures of the console's contract; the
order and the count of the items; the form built from a schema and the answer it builds; and each
outcome of a write (`200`, `401`, `403`, `409`, `422`, no answer). `elm-review` and the CI build of
the Mnemo entry SHALL pass.

#### Scenario: A changed shape

- **WHEN** a field of the inbox fixture is renamed and the decoder is not changed
- **THEN** the decoder test fails

#### Scenario: Keyboard

- **WHEN** the view is driven by keyboard only
- **THEN** an item can be opened, an option chosen, a name typed and the decision sent

#### Scenario: A colour literal

- **WHEN** a module of the view holds a colour literal
- **THEN** the token lint fails
