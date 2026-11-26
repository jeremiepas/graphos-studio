module Mnemo.Fixtures exposing
    ( graphJson
    , orchestratorGoneJson
    , orchestratorLiveJson
    , orchestratorNeverJson
    , orchestratorWordsJson
    , runJson
    , runsJson
    , sessionJson
    , stepRunJson
    )

{-| The five console API fixtures, copied from the `console-api` and
`console-spaces` contract. The JSON lives in `tests/Mnemo/fixtures/`; these
constants are the copy `elm-test` can read. `.scripts/fixture-drift-check.sh`
fails when the two diverge.
-}


sessionJson : String
sessionJson =
    """
{
  "space": "console",
  "spaces": ["console", "graphos-studio"],
  "csrf": "csrf-token-of-the-session",
  "poll": 2,
  "digest": "9f2c1a7e"
}
"""


runsJson : String
runsJson =
    """
{
  "runs": [
    {
      "key": "run|console|r1",
      "workflow": "dev-plan",
      "status": "running",
      "started": "2026-11-26T09:00:00Z",
      "ended": null,
      "stopped_by": null,
      "step_runs": 3,
      "waiting": 1,
      "tokens": { "card": 1200, "prompt": 3400 }
    },
    {
      "key": "run|console|r2",
      "workflow": "dev-plan",
      "status": "passed",
      "started": "2026-11-26T08:00:00Z",
      "ended": "2026-11-26T08:24:00Z",
      "stopped_by": null,
      "step_runs": 4,
      "waiting": 0,
      "tokens": { "card": 800, "prompt": 2100 }
    },
    {
      "key": "run|console|r3",
      "workflow": "release",
      "status": "waiting",
      "started": "2026-11-26T07:30:00Z",
      "ended": null,
      "stopped_by": null,
      "step_runs": 1,
      "waiting": 1,
      "tokens": { "card": 0, "prompt": 0 }
    }
  ],
  "digest": "3b7d0c11"
}
"""


runJson : String
runJson =
    """
{
  "run": {
    "key": "run|console|r1",
    "workflow": "dev-plan",
    "status": "running",
    "started": "2026-11-26T09:00:00Z",
    "ended": null,
    "stopped_by": null,
    "step_runs": 3,
    "waiting": 1,
    "tokens": { "card": 1200, "prompt": 3400 }
  },
  "steps": [
    {
      "id": "plan",
      "status": "passed",
      "reason": null,
      "step_runs": [
        {
          "key": "run|console|r1/plan/1",
          "item": null,
          "attempt": 1,
          "status": "passed",
          "reason": null,
          "started": "2026-11-26T09:00:01Z",
          "ended": "2026-11-26T09:04:12Z"
        }
      ]
    },
    {
      "id": "code",
      "status": "running",
      "reason": null,
      "step_runs": [
        {
          "key": "run|console|r1/code/1",
          "item": 0,
          "attempt": 2,
          "status": "running",
          "reason": null,
          "started": "2026-11-26T09:04:20Z",
          "ended": null
        }
      ]
    },
    {
      "id": "gate",
      "status": "waiting",
      "reason": null,
      "step_runs": []
    }
  ],
  "digest": "b14e6a02"
}
"""


graphJson : String
graphJson =
    """
{
  "run": "run|console|r1",
  "workflow": "dev-plan",
  "nodes": [
    { "id": "plan", "executor": "llm", "layer": 0, "foreach": false },
    { "id": "code", "executor": "delegate", "layer": 1, "foreach": true },
    { "id": "docs", "executor": "command", "layer": 1, "foreach": false },
    { "id": "gate", "executor": "human", "layer": 2, "foreach": false }
  ],
  "edges": [
    { "from": "plan", "to": "code", "implied": false },
    { "from": "plan", "to": "docs", "implied": false },
    { "from": "code", "to": "gate", "implied": false },
    { "from": "docs", "to": "gate", "implied": false },
    { "from": "plan", "to": "gate", "implied": true }
  ],
  "digest": "5c2a9d10"
}
"""


stepRunJson : String
stepRunJson =
    """
{
  "key": "run|console|r1/code/1",
  "item": 0,
  "attempt": 2,
  "status": "running",
  "reason": null,
  "started": "2026-11-26T09:04:20Z",
  "ended": null,
  "card_tokens": 1200,
  "prompt_tokens": 3400,
  "card": [
    {
      "key": "note|console|context",
      "tier": 1,
      "score": 0.92,
      "reason": null
    }
  ],
  "digest": "d7e0b3f4"
}
"""


{-| Recorded on 2026-11-26 by `mnemo orchestrate status --json` (built from
`main` of `poc-graphos`, commit 45c789b) on a space an `mnemo orchestrate`
loop held, then on the same space once the loop was interrupted, then on a
space nothing ever held. The three files are `tests/Mnemo/fixtures/orchestrator/`.
-}
orchestratorLiveJson : String
orchestratorLiveJson =
    """
{"causes":["decided","granted"],"held":0,"last_heartbeat":"2026-11-26T22:25:08Z","launched":0,"left_to_person":0,"live":true,"runs":[],"sequence":1}
"""


orchestratorGoneJson : String
orchestratorGoneJson =
    """
{"causes":["decided","granted"],"held":0,"last_heartbeat":"2026-11-26T22:25:08Z","launched":0,"left_to_person":0,"live":false,"runs":[],"sequence":1}
"""


orchestratorNeverJson : String
orchestratorNeverJson =
    """
{"causes":[],"held":null,"last_heartbeat":null,"launched":null,"left_to_person":null,"live":false,"runs":[],"sequence":null}
"""


{-| The seven words and one the command does not know (`queued`), derived from
the recorded output of the `graphos-studio` space of 2026-11-26. The words
`moves`, `later` and `remediation` could not be produced on a recorded space;
`verification.md` lists them and says how this file was derived.
-}
orchestratorWordsJson : String
orchestratorWordsJson =
    """
{
  "live": true,
  "last_heartbeat": "2026-11-26T22:25:08Z",
  "sequence": 42,
  "held": 1,
  "launched": 1,
  "left_to_person": 4,
  "causes": ["decided", "granted"],
  "runs": [
    {
      "run": "held-run",
      "status": "running",
      "word": "held",
      "reason": "a process works on it",
      "log_file": null
    },
    {
      "run": "moves-run",
      "status": "waiting",
      "word": "moves",
      "reason": "the cause decided",
      "log_file": null
    },
    {
      "run": "later-run",
      "status": "waiting",
      "word": "later",
      "reason": "the back-off of unreachable has not passed: due at 2026-11-26T22:35:08Z",
      "log_file": null
    },
    {
      "run": "waits-run",
      "status": "waiting",
      "word": "waits",
      "reason": "step approve-s3 waits for an approval",
      "log_file": null
    },
    {
      "run": "failed-run",
      "status": "failed",
      "word": "failed",
      "reason": "step code failed: exit_code: 127",
      "log_file": null
    },
    {
      "run": "remediation-run",
      "status": "waiting",
      "word": "remediation",
      "reason": "the launches of this run did not take",
      "log_file": "/home/console/.local/state/mnemo/orchestrator/console/remediation-run.log"
    },
    {
      "run": "off-run",
      "status": "stopped",
      "word": "off",
      "reason": "the run is not moved: no cause applies",
      "log_file": null
    },
    {
      "run": "queued-run",
      "status": "waiting",
      "word": "queued",
      "reason": "a queue added in a later slice holds it",
      "log_file": null
    }
  ]
}
"""
