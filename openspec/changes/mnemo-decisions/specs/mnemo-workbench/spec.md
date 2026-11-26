## MODIFIED Requirements

### Requirement: The page stays usable when the API fails

When a read fails, the page SHALL keep the last data it showed, SHALL show a stale or error notice
naming the route, and SHALL offer a retry. A `401` SHALL show the session-expired message. The page
MUST NOT write anything except the space selection and the decisions of the `mnemo-decisions`
capability (an approval, an answer, a resume, and a turn that asks for another attempt), each
through the console's own write route; it MUST NOT carry a credential, a password or a model
endpoint, and MUST NOT turn a failure into an empty space or an empty run list.

#### Scenario: The API is unreachable

- **WHEN** a poll of `/api/runs` fails
- **THEN** the last groups stay, a notice names `/api/runs`, and a retry is offered

#### Scenario: The session expires

- **WHEN** a read answers `401`
- **THEN** the page says the session expired and keeps the last data behind the message

#### Scenario: No other write

- **WHEN** the page is used for a whole session: spaces selected, runs opened, decisions made
- **THEN** every request other than a `GET` is the space selection or a write of a decision, and
  none cancels a run
