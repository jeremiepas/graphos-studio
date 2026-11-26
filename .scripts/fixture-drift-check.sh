#!/usr/bin/env bash
# Drift check for studio/tests/fixtures/graph.json (`studio-data-sources` 2.1).
#
# Elm tests cannot read files, so two copies of the contract fixture exist:
#   - the on-disk JSON (studio/tests/fixtures/graph.json): the human-editable
#     source of truth.
#   - the `fixtureJson` constant in studio/tests/Fixtures.elm: the embedded copy
#     the decoder round-trip test drives.
#
# This step fails when the two diverge, so an edited fixture without a matching
# constant (or vice-versa) is caught here rather than at runtime. Both sides are
# parsed and canonicalized (keys sorted, numbers normalized) before comparison,
# so key order and int-vs-float formatting never count as drift — only real
# data differences do.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."   # into studio/

python3 - <<'PY'
import json
import re
import sys

FIX = "tests/fixtures/graph.json"
FIXTURES = "tests/Fixtures.elm"


def canonicalize(obj):
    if isinstance(obj, dict):
        return {k: canonicalize(obj[k]) for k in sorted(obj)}
    if isinstance(obj, list):
        return [canonicalize(v) for v in obj]
    if isinstance(obj, bool):
        return obj
    if isinstance(obj, (int, float)):
        return float(obj)
    return obj


fixture = canonicalize(json.load(open(FIX)))

text = open(FIXTURES).read()
m = re.search(
    r"\nfixtureJson : String\nfixtureJson =\n\s*\"\"\"(.*?)\"\"\"",
    text,
    re.S,
)
if not m:
    print("fixtureJson constant not found in Fixtures.elm", file=sys.stderr)
    sys.exit(2)

constant = canonicalize(json.loads(m.group(1)))

if fixture == constant:
    print("OK: graph.json matches Fixtures.fixtureJson")
else:
    print("DRIFT: graph.json != Fixtures.fixtureJson", file=sys.stderr)
    sys.exit(1)

# `mnemo-workbench` and `mnemo-orchestrator-view`: the console API fixtures and
# the recorded `mnemo orchestrate status --json` answers are copied into
# tests/Mnemo/fixtures/ and embedded in tests/Mnemo/Fixtures.elm, because
# elm-test cannot read files.
MNEMO_FIXTURES = "tests/Mnemo/Fixtures.elm"
mnemo = [
    ("session", "sessionJson"),
    ("runs", "runsJson"),
    ("run", "runJson"),
    ("graph", "graphJson"),
    ("step-run", "stepRunJson"),
    ("orchestrator/live", "orchestratorLiveJson"),
    ("orchestrator/gone", "orchestratorGoneJson"),
    ("orchestrator/never", "orchestratorNeverJson"),
    ("orchestrator/words-derived", "orchestratorWordsJson"),
]

mnemo_text = open(MNEMO_FIXTURES).read()
for name, constant_name in mnemo:
    path = "tests/Mnemo/fixtures/" + name + ".json"
    on_disk = canonicalize(json.load(open(path)))
    match = re.search(
        r"\n" + constant_name + r" : String\n" + constant_name + r" =\n\s*\"\"\"(.*?)\"\"\"",
        mnemo_text,
        re.S,
    )
    if not match:
        print(constant_name + " constant not found in " + MNEMO_FIXTURES, file=sys.stderr)
        sys.exit(2)
    embedded = canonicalize(json.loads(match.group(1)))
    if on_disk == embedded:
        print("OK: " + path + " matches " + constant_name)
    else:
        print("DRIFT: " + path + " != " + constant_name, file=sys.stderr)
        sys.exit(1)
PY
