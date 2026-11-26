## Purpose

Provides a single, reproducible developer environment: `devenv up` starts the
studio frontend and the Graphos and mnemo services from verified, version-pinned
artifacts, with explicit configuration paths that default under the user's home.

## ADDED Requirements

### Requirement: One-command startup and shutdown

`devenv up` SHALL start three supervised services — the studio frontend, the
Graphos query API and the mnemo web console — in the foreground, and Ctrl-C (or
`devenv processes down` after a background `devenv processes start`) SHALL stop
them.
Each service SHALL be reachable at its documented address: the studio at
`http://127.0.0.1:8090/`, the Graphos API at
`http://127.0.0.1:8080/api/query?q=probe&budget=1` (with the served graph at
`http://127.0.0.1:8080/graph.json`) and the mnemo console at
`http://127.0.0.1:7482/`.

#### Scenario: Fresh checkout starts connected

- **WHEN** the pinned artifacts are in the local cache and a developer runs `devenv up`
- **THEN** the studio is served on port 8090, `GET http://127.0.0.1:8080/api/query?q=probe&budget=1` and `GET http://127.0.0.1:8080/graph.json` succeed, and the mnemo console accepts connections on port 7482

#### Scenario: Shutdown stops every service

- **WHEN** a developer runs `devenv up` and stops it with Ctrl-C, or runs `devenv processes down` after `devenv processes start`
- **THEN** ports 8090, 8080 and 7482 stop accepting connections

### Requirement: Pinned and verified service artifacts

The stack SHALL obtain each service from a checked-in pin that names the
artifact source and version: a GitHub release asset with its published SHA-256,
or a source revision built into the local cache. It SHALL verify a release asset
against its published SHA-256, SHALL record and verify the hash of a locally
built artifact to detect cache corruption, SHALL fail closed without starting
the affected service on a mismatch, and SHALL reuse an already verified artifact
instead of fetching or rebuilding it.

#### Scenario: Checksum mismatch stops the service

- **WHEN** the cached or downloaded artifact's SHA-256 differs from the pin
- **THEN** the affected process exits non-zero with a message naming the pin and the expected hash, and no service starts from that artifact

#### Scenario: Verified artifact is reused

- **WHEN** `devenv up` runs a second time with a verified artifact in the cache
- **THEN** the stack does not download or rebuild that artifact and the service starts from the cached copy

#### Scenario: Unsupported platform fails before fetching

- **WHEN** the host is not Linux x86_64
- **THEN** the Graphos process exits non-zero with a message naming the supported platform and does not download a binary

### Requirement: Explicit configuration paths with user-home defaults

The stack SHALL resolve `GRAPHOS_CONFIG` to `$HOME/.config/graphos/graphos.yaml`
and `MNEMO_CONFIG` to `$HOME/.config/mnemo/graphos-studio.yaml` by default, SHALL
export both in the dev shell, and SHALL pass the mnemo path explicitly to `mnemo
up` and `mnemo web`. Because `graphos serve` accepts flags rather than a
configuration file, the stack SHALL pass `--graph`, `--dir`, `--port` and
`--host` explicitly, SHALL serve static files so the studio can fetch
`/graph.json` (the pinned server has no slice API), and SHALL document that
`GRAPHOS_CONFIG` governs graph building. An environment override SHALL change
the path used without editing the repository.

#### Scenario: Defaults point under the user's home

- **WHEN** the stack starts with neither variable set
- **THEN** `GRAPHOS_CONFIG` is `$HOME/.config/graphos/graphos.yaml`, `MNEMO_CONFIG` is `$HOME/.config/mnemo/graphos-studio.yaml`, and mnemo is invoked with that file

#### Scenario: Override redirects a service

- **WHEN** a developer exports `MNEMO_CONFIG=/tmp/other-space.yaml` before `devenv up`
- **THEN** mnemo reads `/tmp/other-space.yaml` and the repository is unchanged

### Requirement: Graph source selection

The stack SHALL serve the graph named by `GRAPHOS_GRAPH`, defaulting to
`graphos-out/graph.json` when that file exists and to `tests/fixtures/graph.json`
otherwise. The selected graph SHALL be published as `/graph.json` from the
served directory. The contract fixture's `community_aggregates` SHALL be removed
from the published copy because the pinned server cannot decode their numeric
ids; the studio synthesizes aggregates from node community ids. When neither
path exists, the Graphos process SHALL exit non-zero with a message naming
`GRAPHOS_GRAPH` instead of serving an empty API.

#### Scenario: Fixture serves a clean checkout

- **WHEN** `graphos-out/graph.json` is absent and the checkout contains `tests/fixtures/graph.json`
- **THEN** the Graphos service publishes the fixture as `/graph.json` (without `community_aggregates`) and `GET /graph.json` returns a graph the studio decodes

#### Scenario: Missing graph fails clearly

- **WHEN** neither the default graph nor the fixture exists and `GRAPHOS_GRAPH` is unset
- **THEN** the Graphos process exits non-zero and its log names `GRAPHOS_GRAPH` and the two candidate paths

### Requirement: Frontend is built before it is served

The studio process SHALL run an optimized `elm make` build into
`public/studio.js` before starting the static server, and SHALL exit non-zero
without serving when the build fails.

#### Scenario: Compile error prevents serving a stale bundle

- **WHEN** the Elm sources contain a compile error and `devenv up` starts the studio
- **THEN** the studio process exits non-zero with the compiler output and port 8090 is not served

### Requirement: Stack preflight

`devenv tasks run dev-stack:check` SHALL verify the pin manifest, the presence
and checksums of the cached artifacts, the resolved configuration paths (the
mnemo file must exist; the Graphos one is reported and may be absent), the
selected graph and the availability of ports 8090, 8080 and 7482. It SHALL exit
zero only when every check passes and SHALL list each failing check with a
remediation hint.

#### Scenario: Incomplete cache is reported

- **WHEN** the preflight runs before the artifacts are fetched
- **THEN** it exits non-zero and lists the missing artifacts and the command that fetches them

#### Scenario: Ready stack passes

- **WHEN** the artifacts are verified, the mnemo configuration exists, a graph is selected and the ports are free
- **THEN** the preflight exits zero and prints the three service URLs

### Requirement: Mnemo memory graph is up before the console

The mnemo process SHALL ensure the Neo4j memory graph is running by invoking the
idempotent command `mnemo up` before starting `mnemo web`, and SHALL exit
non-zero with a diagnostic if the memory graph cannot be started.

#### Scenario: Console waits for Neo4j

- **WHEN** Neo4j is stopped and the mnemo process starts
- **THEN** it starts the memory graph with `mnemo up` and only then binds the console on 127.0.0.1:7482

#### Scenario: Neo4j failure is visible

- **WHEN** `mnemo up` fails
- **THEN** the mnemo process exits non-zero with the failure output and never starts a console against an absent graph
