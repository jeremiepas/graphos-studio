# Verification

Record of the contract the page is built against, the baseline, and what waits for
the console. Measurements go here with the date and the command.

## Dev stack and the command

| Field | Value |
|---|---|
| Elm pin | `0.19.2` (`dev-stack/pins.json`, the nixpkgs revision `.github/workflows/studio.yml` pins) |
| Toolchain | `elm 0.19.2`, `elm-test 0.19.2-1`, `elm-format 0.8.8`, `elm-review 2.13.5` |
| CI task | `devenv tasks run studio:ci` (build · `elm-test` · `elm-review` · fixture drift · Mnemo entry · token lint) |
| Baseline | `studio:ci` green, 176 tests, on 2026-11-27, before this change |

The change is built and tested against fixtures (`tests/Mnemo/fixtures/provisional/`),
the same way `mnemo-workbench` and `mnemo-orchestrator-view` were. No test reaches a
console.

## The console the page reads today

Read on 2026-11-27 in `poc-graphos` (`mnemo/src/Mnemo/Infrastructure/Console.hs`), the
second copy the summary lists. The page reads:

| Route | Served today | Used by |
|---|---|---|
| `GET /api/session` | yes | spaces, selected space, poll, CSRF |
| `GET /api/runs` | yes | the run list |
| `GET /api/runs/<run>` | yes | the selected run's detail |
| `GET /api/runs/<run>/graph` | yes | the graph of a run |
| `GET /api/step-runs/<step-run>` | yes | a step node's status |
| `GET /api/orchestrator` | yes | the orchestrator view |
| `POST /api/session/space` | yes | the space selection, with `X-CSRF-Token` |

## The three the reruns need but the console lacks

Each is a Mnemo change in `poc-graphos`; the page is built and tested against fixtures
of that contract and its live check (5.1) waits for them.

| Rerun | Console route/command the design assumes | Status today |
|---|---|---|
| A note on a space | `POST /api/session/space` gains `note` and `tags` in the body, answers `200` with the saved note | **not present** |
| A run or a workflow | a rerun of a run or a workflow (the design assumes `POST /api/runs/<run>/rerun`) | **not present** |
| The orchestrator's heartbeat | a re-run of the orchestrator's heartbeat (the design assumes `POST /api/orchestrator/heartbeat`) | **not present** |

**A rerun the console does not yet serve is hidden.** Until the console serves a rerun,
the section shows only the view's rerun, which the console has. The console is the judge
of a rerun; the page never marks a rerun done before the console records it.

## 1.3 — blocked, and why

Task 1.3 builds Mnemo from `main` of `poc-graphos` outside this repository, in a space
made for it, and records `mnemo orchestrate status --json` (and its exit code) for an
orchestrator that holds the space, none after one ran, and a space with no run.

`poc-graphos` is **not reachable** from this repository (`/home/jeremie/Documents/poc-graphos`
does not exist). So 1.3, the reruns that need the console commands (4.2), and the live
check (5.1) cannot run against a live console today. The page instead meets a console
without them and keeps the note (read and written through the space route's assumed contract), hiding the rerun controls that need them, showing only the view's
rerun. The controls the console does not yet serve stay hidden until the console's
contract replaces the assumption.

## Fixtures

`tests/Mnemo/fixtures/provisional/` holds the assumed contract, each with the request
(the session, the write header `X-CSRF-Token`, the body) and the answer.

| File | Answer |
|---|---|
| `notes-write/success.json` | `200`, the note saved |
| `notes-write/forbidden.json` | `403` |
| `notes-write/no-space.json` | `404` |
| `rerun-run/success.json` | `200` with the run |
| `rerun-orchestrator/success.json` | `200` with the heartbeat |

## Measurements

2026-11-27 · `devenv tasks run studio:ci` · build `Main ──> public/studio.js`, 176 tests
passed, `elm-review` clean, fixture drift clean, baseline green before the change.
