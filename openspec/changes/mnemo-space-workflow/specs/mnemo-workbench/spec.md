## MODIFIED Requirements

### Requirement: The page stays usable when the API fails

When a read fails, the page SHALL keep the last data it showed, SHALL show a stale or error notice
naming the route, and SHALL offer a retry. A `401` SHALL show the session-expired message. The page
MUST NOT write anything except the space selection, saving a note or tags on the selected space, or
a rerun of a run, the orchestrator or the view; it MUST NOT carry a credential, a password or a
model endpoint, and MUST NOT turn a failure into an empty space or an empty run list.

#### Scenario: The API is unreachable

- **WHEN** a poll of `/api/runs` fails
- **THEN** the last groups stay, a notice names `/api/runs`, and a retry is offered

#### Scenario: The session expires

- **WHEN** a read answers `401`
- **THEN** the page says the session expired and keeps the last data behind the message

#### Scenario: A note is refused

- **WHEN** saving a note on the space answers `404` or `403`
- **THEN** the page keeps the last note and shows the error

#### Scenario: A rerun is refused

- **WHEN** a rerun answers `401`, `403` or `409`
- **THEN** the page keeps the last state and shows the console's decision
