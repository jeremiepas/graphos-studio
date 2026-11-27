# Tasks

Each group writes its checks before its code. Every build and test runs through `devenv shell`.
No test reaches a console: the answers come from the fixtures. Decision numbers refer to
`design.md`; requirement and scenario names are those of the two specs. Each group ends with
`devenv tasks run studio:ci` green. Measurements go, with the date and the command, in
`verification.md` of this change. The graph Studio is not changed.

## 1. The contract and the baseline

- [ ] 1.1 Record in `verification.md` what the pinned Mnemo of the dev stack serves under `/api` and which write routes it has (from its source at the pin), and whether `mnemo/test/fixtures/console-api/` exists in `poc-graphos` at that pin.
- [ ] 1.2 Write the fixtures of the contract into `tests/Mnemo/fixtures/provisional/` (or copy the emitted files into `tests/Mnemo/fixtures/` when they exist): the inbox with one approval, one question with an enumeration, one question with a text and a boolean, one question with a list of objects, and one decided item; the attention list with a failed step that offers `retry` and a run that offers `resume`; the answer of approve, answer, resume and retry for `200`, and of `401`, `403`, `409`, `422`. Add a step to `studio:ci` that prints the name of every file under `provisional/` (it does not fail the build); check first that it prints nothing on `main` and the new files on this branch.
- [ ] 1.3 A person's step, read-only on the memory graph of the `graphos-studio` space: for each approval and answer already stored, the time between the moment the step started to wait and the decision, and between the decision and the next resume of its run. Record the figures, the number of decisions counted and the query, as the baseline of the hypothesis.

## 2. The decoders

- [ ] 2.1 Checks first: one decoder test per fixture of 1.2, and a test that a renamed field fails the decoder (scenario *A changed shape*). Record whether a new Elm dependency is needed (expected: none).
- [ ] 2.2 Add the types and decoders of an inbox item, an attention entry, an action and the answer of a write to `src/Mnemo/Decode.elm`, and the two reads to `src/Mnemo/Api.elm`; make 2.1 pass.

## 3. The list and the number

- [ ] 3.1 Checks first, on pure functions: the order (inbox items oldest first, then the attention entries that offer `retry` or `resume`, other kinds left out), the number of items that wait (a decided item does not count), and the five scenarios of *The decisions view lists what waits for a person* on the update and view of the page.
- [ ] 3.2 Add the decisions view to the Mnemo entry (decision 1), the two reads to the poll, and the unchanged-`digest` rule (decision 9); make 3.1 pass. A console that answers `404` on `/api/inbox` hides the view and says why (test first).

## 4. The options of a question

- [ ] 4.1 Checks first, on pure functions: a schema becomes a form description for an enumeration, a boolean, a string, a number and an integer, with the required mark; any other schema or field becomes the JSON fallback; the form's state becomes the JSON answer. The four scenarios of *A question shows its options*.
- [ ] 4.2 Add the form module and its view (decision 4); make 4.1 pass.

## 5. Approve and answer

- [ ] 5.1 Checks first: the request of each write (its route, `X-CSRF-Token`, `Accept: application/json`, the name, the answer) and the state of an item after each outcome (waiting, sending, decided, refused, failed), for the seven scenarios of *A person decides from the page*.
- [ ] 5.2 Add the two writes to `Api.elm` and the item states to the model (decision 5), with the name kept in the model only (decision 6); make 5.1 pass.
- [ ] 5.3 Check first: the scenario *No other write* of `mnemo-workbench`, as a test that lists every non-`GET` request the update can produce and finds no cancel. Then make it pass.

## 6. Resume

- [ ] 6.1 Checks first: the three scenarios of *A decided run can be resumed from the page* (offered after the only waiting step is decided, not offered while another waits, the console's refusal shown).
- [ ] 6.2 Add the resume write and its control; make 6.1 pass.

## 7. One more attempt for a failed step

- [ ] 7.1 Checks first: the scenarios *One more attempt for a failed step* and *A retry the console refuses*, with the request holding the step, the name and the note.
- [ ] 7.2 Add the retry write and its control with a note; make 7.1 pass.

## 8. Links, design system and keyboard

- [ ] 8.1 Checks first: the three scenarios of *The runs lead to the decision* (from the run list, from a waiting node of the graph with its text mark, from an item to its run).
- [ ] 8.2 Add the links and the waiting mark of a node; make 8.1 pass.
- [ ] 8.3 Checks first: the scenarios *Keyboard* and *A colour literal* of *The view follows the design system and is tested*, and that an error is rendered next to its control. Then use the components of `Studio.DesignSystem` for the list, the form and the actions, and make them pass.
- [ ] 8.4 Check first: a grep of `README.md` for the decisions view (none before the edit). Then the README: the view, what it writes and what it never writes, the provisional fixtures.

## 9. The turn at a waiting approval

- [ ] 9.1 A person's step, in `poc-graphos`: propose the Mnemo change that lets a person ask for changes at a waiting approval (the use case, its write, the action in the inbox item, the fixture). Record its name here, and replace the assumption of decision 3 (the action name `revise`, a name and a note) with its contract.
- [ ] 9.2 Checks first, on a fixture of an approval that offers the action and one that does not: the scenarios *Ask for changes at an approval*, *The console does not offer the turn* and *A turn without a note*.
- [ ] 9.3 Add the control and its write, shown only for an item that offers the action (decision 3); make 9.2 pass.
- [ ] 9.4 Checks first: the scenario *The next proposal is approved*, with a run fixture whose step has two attempts: the earlier turn is shown under attempt 2 with its note and author (decision 7). Then fetch the run of an opened item and show the turns; make it pass.

## 10. The live check

- [ ] 10.1 When `mnemo-console-in-studio` is applied in `poc-graphos`: move the Mnemo pin of the dev stack, replace every provisional fixture by the emitted file until `provisional/` is empty, and record in `verification.md` each difference of shape found and the decoder change it needed.
- [ ] 10.2 With `devenv up`, in a space made for the check: a workflow with an approval, a question with three options and a step that fails. From the page, by keyboard only: approve, answer, resume, grant one more attempt with a note. Record each write and the console's answer, and that `mnemo status` shows the same decisions with their author.
- [ ] 10.3 Two browsers on the same item: the second decision gets the `409` and shows the first. Record it.
- [ ] 10.4 After two weeks of use, repeat the query of 1.3 and record the two figures next to the baseline. They are an observation of one person's use, not a result for the hypothesis.
