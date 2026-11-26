# Verification

Measurements of this change, with the date and the command. Nothing here reaches a
console or an orchestrator at test time; the fixtures are recorded answers.

## 1.1 The pin, and the build that has the command

Measured on 2026-11-26.

- **Dev-stack pin.** `dev-stack/pins.json` pins `jeremiepas/poc-graphos` at
  `d5d7b6e3cb66e46b8cc52d854cdd00e083b36cbe`, `mnemo/`, version `0.1.0.0`.
- **The pin has no `status` subcommand.** `git cat-file -e
  d5d7b6e3cb66e46b8cc52d854cdd00e083b36cbe:mnemo/src/Mnemo/UseCase/OrchestrateStatus.hs`
  says the path is absent, and `git show
  d5d7b6e3cb66e46b8cc52d854cdd00e083b36cbe:mnemo/app/Main.hs | grep -c 'orchestrate status'`
  answers `0`. The build the `graphos-studio` wrapper used answered
  `Invalid argument 'status'` with exit `2`.
- **The first commit with the command.**
  `75b1dc76ba13dc1a608b631369e245765c93a1e7` — `mnemo-orchestrator: slice 2 (#15)`,
  which adds `mnemo/src/Mnemo/UseCase/OrchestrateStatus.hs`.
- **The build used for the fixtures.** `main` at `45c789b` (`mnemo-v0.1.0.0-3-g45c789b`),
  built outside this repository with `cabal build exe:mnemo` under GHC 9.10.3
  (the same compiler `devenv.nix` provides).

## 1.2 The recorded answers

Command, from `poc-graphos/mnemo`:

```console
$ MNEMO_CONFIG=$HOME/.config/mnemo/graphos-studio.yaml \
    mnemo orchestrate status --space SPACE --json
```

### An orchestrator holds the space

A space made for the check (`orchestrator-view-check`) while `mnemo orchestrate
--space orchestrator-view-check --interval 30` ran; exit code `0`:

```json
{"causes":["decided","granted"],"held":0,"last_heartbeat":"2026-11-26T22:25:08Z","launched":0,"left_to_person":0,"live":true,"runs":[],"sequence":1}
```

→ `tests/Mnemo/fixtures/orchestrator/live.json`.

### None, after one ran

The same space after the loop was interrupted with `SIGINT`; exit code `1`:

```json
{"causes":["decided","granted"],"held":0,"last_heartbeat":"2026-11-26T22:25:08Z","launched":0,"left_to_person":0,"live":false,"runs":[],"sequence":1}
```

→ `tests/Mnemo/fixtures/orchestrator/gone.json`.

### A space never held

The space `orchestrator-view-never`, nothing ever run on it; exit code `1`:

```json
{"causes":[],"held":null,"last_heartbeat":null,"launched":null,"left_to_person":null,"live":false,"runs":[],"sequence":null}
```

→ `tests/Mnemo/fixtures/orchestrator/never.json`.

### Runs and words

`mnemo orchestrate status --json` on the `graphos-studio` space, exit code `1`:

```json
{"causes":[],"held":null,"last_heartbeat":null,"launched":null,"left_to_person":null,"live":false,"runs":[{"log_file":null,"reason":"step prepare failed: exit_code: 127","run":"openspec-release-20261126T221804-28df","status":"failed","word":"failed"},{"log_file":null,"reason":"a process works on it","run":"openspec-release-20261126T221933-8203","status":"running","word":"held"}],"sequence":null}
```

and on the `homelab` space, which produced `waits` and `off`:

```json
{"run":"delivery-deploy-i2p-anonymous-share-20261123T200359Z","status":"waiting","word":"waits","reason":"step s10 waits for an approval","log_file":null}
{"run":"agent-zero-syncwave-deadlock-20261124T225051-342b","status":"stopped","word":"off","reason":"no orchestrator holds the space","log_file":null}
```

| Word | Produced by a recorded space? |
|---|---|
| `held` | yes (`graphos-studio`) |
| `failed` | yes (`graphos-studio`, `homelab`, `graphos`) |
| `waits` | yes (`homelab`) |
| `off` | yes (`graphos-studio`, `homelab`) |
| `moves` | no |
| `later` | no |
| `remediation` | no |
| `queued` (unknown to the page) | no |

`moves`, `later` and `remediation` need a live orchestrator over a decided run, a
back-off and a failed launch; no recorded space was in those states on 2026-11-26.
`tests/Mnemo/fixtures/orchestrator/words-derived.json` is derived from the recorded
`graphos-studio` list: the eight entries keep the `run`, `status`, `reason` and
`log_file` field names and take the word and reason the command gives for each
case (read in `poc-graphos/mnemo/src/Mnemo/UseCase/OrchestrateStatus.hs`,
`classifyRun`). The file is named `-derived` and the fixture comment says so.

### The shape of the JSON, and what only the text output has

The JSON object holds: `live`, `last_heartbeat` (ISO-8601 or `null`), `sequence`,
`held`, `launched`, `left_to_person`, `causes` (names), and `runs`, each with
`run`, `status`, `word`, `reason`, `log_file` (a path or `null`, present only for
a run a heartbeat launched).

Fields the text output has and the JSON has not:

- **The cap of runs** (`orchestrator.max_runs`): the text output never prints it
  either; it prints `the cap of N runs is reached` inside a `later` reason. There
  is no field for it, so the view shows it only when a reason carries it.
- **A due time of its own**: `later` carries the time inside `reason`
  (`due at <ISO time>`); there is no `due_at` field.
- **The workflow of a run**: the command has no workflow field; the page joins the
  workflow from `/api/runs` by the run's name.
- **Endpoint/profile details** of an unreachable run: the text and the JSON both
  say only `the endpoint is still unreachable at the longest back-off`, with no
  profile list.

## 7.1 Design system, keyboard and states

Measured on 2026-11-26, after the view was written.

- **The view uses no colour literal.** The CI command
  `grep -rnE '#[0-9a-fA-F]{6}' src/ --include='*.elm' | grep -v 'DesignSystem/Tokens.elm'`
  prints nothing; every colour comes from `Studio.DesignSystem.Tokens`. A colour
  literal added to a module of the view fails that lint (task 7.1's scenario
  *A colour literal*).
- **`elm-review`** (`NoUnused.Variables`, `Simplify`) reports `I found no errors!`.
- **Keyboard.** The state is a text in the header (`id="orchestrator-state"`); a
  line's control is a real `<button>` (`UI.btn`), so it takes focus and is
  activated by Enter or Space. `tests/Mnemo/OrchestratorTest.elm` checks that the
  state, a line and its button are present, and that a click dispatches
  `SelectRun` with the run's full key.
- **One test per state:** loading, live, gone, never held, not served, stale and
  session expired are in `tests/Mnemo/OrchestratorTest.elm`.

## 7.2 README

`git show HEAD:README.md | grep -i orchestrator` printed nothing before the edit.
The README now has an *Orchestrator view* subsection under *Mnemo page*: the
state and heartbeat, the seven words, that it controls nothing, that it shows
"not served" until the console has `/api/orchestrator`, and where the recorded
answers live.
