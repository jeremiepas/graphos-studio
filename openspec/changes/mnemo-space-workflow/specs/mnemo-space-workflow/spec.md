## Purpose

The Studio page's workflow section for the selected space: a note the page keeps about the space,
and a sub-list of the orchestrator and the graph, each with a rerun.

## ADDED Requirements

### Requirement: The page keeps a free-text note and tags on the selected space

The workflow section SHALL let a person write free-text notes and tags for the selected space and
read them back while the space is selected. The note is stored in the console session and is lost at
a reload, as the space selection is. The note says nothing about a run, a workflow or a decision;
it holds only what a person wrote. The note SHALL be shown wherever the section is, and SHALL be
refreshed at the interval `/api/session.poll` names.

#### Scenario: A note is written and read

- **WHEN** a person writes a note for the selected space
- **THEN** the section shows the note for that space, and it is gone at a reload

#### Scenario: A note with tags

- **WHEN** a person writes a note and tags for the space
- **THEN** the section shows the note and its tags

#### Scenario: A space with no note

- **WHEN** a space has no note
- **THEN** the section shows the space and no note

#### Scenario: A refused write

- **WHEN** saving the note answers `404` or `403`
- **THEN** the page keeps the last note and shows the error

### Requirement: The workflow section lists the orchestrator and the graph

For the selected space the section SHALL be a sub-list of two items, `orchestrator` and `graph`.
`orchestrator` SHALL show what holds the space and the state of each run; `graph` SHALL draw the
workflow of a run. Both items SHALL be read from the same session and the same poll as the rest of
the page. A space with no run SHALL say that no run is left and SHALL not draw a graph.

#### Scenario: The two items

- **WHEN** the section is shown for a space
- **THEN** it lists `orchestrator` and `graph` for that space

#### Scenario: No run

- **WHEN** the space has no run
- **THEN** the `graph` item says no run is left and shows no graph

#### Scenario: Another space

- **WHEN** the person selects another space
- **THEN** the section shows the state of that space and nothing of the first

### Requirement: Each thing the section shows can be re-run

The section SHALL offer a rerun for each of the three things it shows: a run or workflow, the
orchestrator, and the view itself. Re-running the view SHALL re-read the orchestrator and the graph;
re-running the orchestrator SHALL ask for a new heartbeat; re-running a run or workflow SHALL start
the work again. Each rerun SHALL go through the console's session and write header, SHALL send no
credential, and SHALL show what the console recorded, never a rerun as done before the console said
so.

#### Scenario: Re-run the view

- **WHEN** a person re-runs the view
- **THEN** the section re-reads the orchestrator and the graph

#### Scenario: A rerun recorded by the console

- **WHEN** a rerun is sent and the console records it
- **THEN** the page shows the console's record, and never the rerun before the record

#### Scenario: A rerun the console refuses

- **WHEN** a rerun answers `401`, `403` or `409`
- **THEN** the page keeps the last state and shows the console's decision
