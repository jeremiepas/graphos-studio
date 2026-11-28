# Tasks

Each group writes its checks before its code. Every build and test runs through `devenv shell`.
No test reaches the console: the notes and the reruns come from the fixtures. Decision numbers refer
to `design.md`; requirement and scenario names are those of the two specs. Each group ends with
`devenv tasks run studio:ci` green. Measurements go, with the date and the command, in
`verification.md` of this change. The graph Studio is not changed.

## 1. The contract and the baseline

- [x] 1.1 Record in `verification.md` the Mnemo pin of the dev stack, the console routes it serves
  today (`/api/session`, `/api/runs`, `/api/runs/<run>`, `/api/runs/<run>/graph`,
  `/api/step-runs/<step-run>`, `/api/orchestrator`, `POST /api/session/space`) and the three the
  reruns need but it lacks (the notes write on a space, a rerun of a run or workflow, a re-run of an
  orchestrator heartbeat).
- [x] 1.2 Write the fixtures of that contract into `tests/Mnemo/fixtures/provisional/`: one space
  notes write that succeeds (`200` with the saved note), one forbidden (`403`), one with no space
  (`404`), one run/workflow rerun (`200` with the run) and one orchestrator re-run (`200` with the
  heartbeat); each with the session, the write header and the answer.
- [ ] 1.3 Build Mnemo from `main` of `poc-graphos` outside this repository, and in a space made for
  it record the output of `mnemo orchestrate status --json` (and its exit code) for: an orchestrator
  that holds the space; none, after one ran; and a space with no run. Copy the outputs into
  `tests/Mnemo/fixtures/provisional/orchestrator/`, and record the fields the JSON holds and the ones
  the text output has and the JSON does not.

## 2. The note the page keeps on the space

- [x] 2.1 `App.elm`: add the note and its tags to the model, typed once while the space is selected
  and reset to empty at a reload.
- [x] 2.2 `Api.elm`: save the note through the space route's body, with the session and the write
  header and no credential.
- [x] 2.3 `Decode.elm`: add the note and its tags to the section.
- [x] 2.4 Add tests: a note is written and read back while the space is selected, shown in the
  section, a refused write keeps the last note and shows the error, and no note is shown when the
  space has none.
- [x] 2.5 Run `devenv tasks run studio:ci` green.

## 3. The workflow section: the orchestrator and the graph in a sub-list

- [x] 3.1 `App.elm`: add the orchestrator and the graph as a sub-list for the selected space, read
  from the same session and the same poll as the runs.
- [x] 3.2 `Api.elm` and `Decode.elm`: read `/api/orchestrator` and `/api/runs/<run>/graph` for the
  section, at the session's interval, with a text for every status.
- [x] 3.3 Add tests: the section lists the two items for a space, a space with no run says no run is
  left and draws no graph, and another space shows the other space.
- [x] 3.4 Run `devenv tasks run studio:ci` green.

## 4. A rerun beside each of the three things the section shows

- [ ] 4.1 `App.elm`: add, per rerun, one of waiting, sending, recorded (with what the console said),
  refused (with the console's decision) and failed (no answer); the control disabled while sending;
  the view changes only when the answer arrives.
- [ ] 4.2 `Api.elm`: map the reruns the console offers to controls and hide a rerun the console does
  not yet serve; the view's rerun goes through the console's route, the session and the write header,
  no credential, and shows what the console recorded.
- [ ] 4.3 Add tests: re-running the view re-reads the orchestrator and the graph, a rerun recorded by
  the console shows its record and never the rerun before the record, and a refused rerun keeps the
  last state and shows the console's decision.
- [ ] 4.4 Run `devenv tasks run studio:ci` green.

## 5. The live check waits for the console

- [ ] 5.1 Write the live check that runs against the console routes and commands the reruns need
  once they are applied in `poc-graphos`; it moves the Mnemo pin of the dev stack and runs the built
  page.
- [x] 5.2 `README.md`: add the section, the note and what it writes, and the reruns beside them.
- [x] 5.3 Run `devenv tasks run studio:ci` green.
