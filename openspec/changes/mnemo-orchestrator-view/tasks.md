# Tasks

Each group writes its checks before its code. Every build and test runs through `devenv shell`.
No test reaches a console or an orchestrator: the answers come from the fixtures. Decision numbers
refer to `design.md`; requirement and scenario names are those of the spec. Each group ends with
`devenv tasks run studio:ci` green. Measurements go, with the date and the command, in
`verification.md` of this change. The graph Studio is not changed.

## 1. The contract and the baseline

- [x] 1.1 Record in `verification.md` the Mnemo pin of the dev stack, that its build refuses `mnemo orchestrate status`, and the commit of `poc-graphos` that first has the command.
- [x] 1.2 Build Mnemo from `main` of `poc-graphos` outside this repository, and in a space made for it record the output of `mnemo orchestrate status --json` (and its exit code) for: an orchestrator that holds the space; none, after one ran; a space never held; and runs that carry each of the seven words. Copy the outputs into `tests/Mnemo/fixtures/orchestrator/`, and write in `verification.md` the fields the JSON holds and the ones the text output has and the JSON has not. A word that could not be produced is listed there, and its fixture is derived from a recorded one with the word changed, and named so.
- [ ] 1.3 A person's step, in `poc-graphos`: propose the route that serves this state under `/api` (its path, its `digest`, the session, the selected space). Record its name here and replace the assumed path of decision 2.
- [ ] 1.4 A person's step: over one week of work in the `graphos-studio` space, note each time a run stayed `waiting` after its decision and how it was noticed. Record the count and the notes as the baseline of the hypothesis.

## 2. The decoder

- [x] 2.1 Checks first: one decoder test per fixture of 1.2, a test that a renamed field fails the decoder (scenario *A changed shape*), and a test that an unknown word decodes to a word shown as given.
- [x] 2.2 Add the types and the decoder to `src/Mnemo/Decode.elm` and the read to `src/Mnemo/Api.elm`; make 2.1 pass.

## 3. Who holds the space, and the last heartbeat

- [x] 3.1 Checks first: the five scenarios of *The view says whether an orchestrator holds the space* (an old heartbeat of a live orchestrator keeps the live state) and the two of *The last heartbeat is shown*.
- [x] 3.2 Add the view to the Mnemo entry and the line of state to the header (decision 1), the read to the poll, and the age of the heartbeat as an age (decision 3); make 3.1 pass.

## 4. The word and the reason of each run

- [x] 4.1 Checks first: the label and the explanation of each of the seven words as pure functions, and the seven scenarios of *Every run that is not final has one word and its reason* (the unknown word, the path of the output file as a text, the link to the run, nothing to move).
- [x] 4.2 Add the list (decision 4); make 4.1 pass.

## 5. The word in the run list

- [ ] 5.1 Checks first: the three scenarios of *The run list carries the word of each run*, with the word matched to a run by its key and no word for a run the answer does not hold.
- [ ] 5.2 Show the word in the run rows from the same read (decision 5); make 5.1 pass, and check that every test of the run list of `mnemo-workbench` still passes unchanged.

## 6. Not served, stale, session expired

- [ ] 6.1 Checks first: the three scenarios of *The view reads and never controls*, with the three states of decision 6 as three values of the model, and a test that lists every request the view's update can produce and finds only `GET`.
- [ ] 6.2 Add the states and their texts; make 6.1 pass.

## 7. Design system, keyboard and documentation

- [ ] 7.1 Checks first: the scenarios *Keyboard* and *A colour literal* of *The view follows the design system and is tested*, and one test per state of the view (loading, live, gone, never held, not served, stale, session expired). Then use the components of `Studio.DesignSystem`; make them pass.
- [ ] 7.2 Check first: a grep of `README.md` for the orchestrator view (none before the edit). Then the README: the view, the seven words, that it controls nothing, and that it shows "not served" until the console has the route.

## 8. The live check

- [ ] 8.1 When the route of 1.3 is merged in `poc-graphos`: move the Mnemo pin of the dev stack, replace the fixtures by the route's own answers, and record in `verification.md` each difference of shape and the decoder change it needed.
- [ ] 8.2 With `devenv up` and `mnemo orchestrate` on a space made for the check: the view says that an orchestrator holds the space; a decided run shows `moves` and then moves; interrupting the orchestrator turns the view to "none" within two poll intervals; a run that waits for an answer shows `waits`. Record each observation, and that `mnemo orchestrate status` says the same.
- [ ] 8.3 After the week that follows the merge, repeat the note of 1.4 and record it next to the baseline. It is an observation of one person's use, not a result for the hypothesis.
