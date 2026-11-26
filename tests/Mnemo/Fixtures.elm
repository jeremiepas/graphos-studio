module Mnemo.Fixtures exposing (graphJson, runJson, runsJson, sessionJson, stepRunJson)

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
