## 1. Pins and artifacts

- [x] 1.1 Add `dev-stack/pins.json` with Graphos `v0.3.0` (`graphos-linux-x86_64`, SHA-256 `c3894f86…`) and the mnemo source pin (`jeremiepas/poc-graphos` at `d5d7b6e3…`, `mnemo/`); verify `jq -e . dev-stack/pins.json` succeeds and the Graphos hash matches the published `.sha256`.
- [x] 1.2 Add `scripts/dev-stack/lib.sh` with the shared root/cache paths, pin readers, `die`, platform guard, SHA-256 helpers, configuration defaults and graph resolution; verify `bash -n scripts/dev-stack/lib.sh` and that sourcing it in a subshell prints the two default paths.
- [x] 1.3 Add `scripts/dev-stack/fetch-graphos.sh` and `scripts/dev-stack/graphos.sh`: download to a temporary file, verify the published SHA-256, move into `.devenv/dev-stack/artifacts/graphos/<version>/`, publish the selected graph at `.devenv/dev-stack/graphos-serve/graph.json`, and `exec graphos serve --graph <published> --dir .devenv/dev-stack/graphos-serve --port 8080 --host 127.0.0.1`; verify a first run fetches, a second run reports the cache, and a corrupted cached binary exits non-zero before serving.
- [x] 1.4 Add `scripts/dev-stack/fetch-mnemo.sh` and `scripts/dev-stack/mnemo.sh`: use `MNEMO_SRC` or `gh repo clone` at the pinned revision, build `exe:mnemo` with `cabal` in `mnemo/`, record the binary hash, run `mnemo up --config "$MNEMO_CONFIG"`, then `exec mnemo web --config "$MNEMO_CONFIG" --host 127.0.0.1 --port 7482`; verify with `MNEMO_SRC=$HOME/Documents/perso/poc-graphos` that the build succeeds, `<cache>/bin/mnemo --help` works, and a second run rebuilds nothing.
- [x] 1.5 Add `curl`, `jq`, `git`, `gh` and `pkg-config` to the devenv packages and a `dev-stack:fetch` task running both fetch scripts; verify `devenv shell -- bash -c 'curl --version >/dev/null && jq --version && gh --version'` and that `devenv tasks run dev-stack:fetch` completes twice without changing the cached artifacts.

## 2. Configuration and graph selection

- [x] 2.1 Export `GRAPHOS_CONFIG` and `MNEMO_CONFIG` from `enterShell` with `${VAR:-$HOME/...}` defaults and resolve the same defaults in `lib.sh`; verify `devenv shell -- bash -c 'printf "%s\n%s\n" "$GRAPHOS_CONFIG" "$MNEMO_CONFIG"'` prints the two home paths, and an exported `MNEMO_CONFIG=/tmp/other.yaml` is preserved.
- [x] 2.2 Implement and verify the graph selection order: `GRAPHOS_GRAPH`, then `graphos-out/graph.json`, then `tests/fixtures/graph.json`; verify an explicit path starts Graphos, a missing explicit path exits with a message naming both candidates, and the fixture is chosen when `graphos-out/` is absent.

## 3. `devenv up` processes

- [x] 3.1 Add the `studio` process and `scripts/dev-stack/studio.sh` (`elm make --optimize` into `public/studio.js`, then `python3 -m http.server --bind 127.0.0.1 -d public 8090`); verify `devenv up` serves the studio on 8090 and a deliberately broken Elm file makes the process exit without binding 8090 (then revert the file).
- [x] 3.2 Add the `graphos` process using the wrapper from 1.3; verify `curl -s 'http://127.0.0.1:8080/api/query?q=probe&budget=1' | jq -e .` and `curl -s http://127.0.0.1:8080/graph.json | jq -e .` return JSON, and that a missing graph makes the process exit with the `GRAPHOS_GRAPH` message instead of serving.
- [x] 3.3 Add the `mnemo` process using the wrapper from 1.4; verify it starts Neo4j with `mnemo up` when needed, the console accepts connections on 127.0.0.1:7482 (use the tokenised URL from its log for an authenticated page), and a forced `mnemo up` failure exits the process without a console.
- [x] 3.4 Run the full one-command path from an empty cache: `devenv up` starts all three services, `curl` reaches 8090, 8080/graph.json, 8080/api/query and 7482, stopping it (Ctrl-C, or `devenv processes start` then `devenv processes down` for a background run) closes the three ports, and a second `devenv up` reuses every cached artifact without downloading or rebuilding one.

## 4. Preflight

- [x] 4.1 Add `scripts/dev-stack/check.sh` that verifies the manifest, both cached artifacts and sidecars, the mnemo configuration file (required), the Graphos configuration (reported, optional), the selected graph, and the three ports via a Python bind; verify it fails on an empty cache with the `dev-stack:fetch` hint and passes after the fetch.
- [x] 4.2 Add the `dev-stack:check` devenv task running the script; verify `devenv tasks run dev-stack:check` exits non-zero with each failing check and hint, and exits zero with the three URLs once ready; verify it also fails when another process already binds 8080.

## 5. Documentation and regression checks

- [x] 5.1 Replace the manual "Build & run" recipe in `README.md` with a "Dev stack" section: `devenv up` and `devenv processes start`/`down`, the pin manifest and how to bump it, `GRAPHOS_CONFIG`/`MNEMO_CONFIG` defaults and overrides, `GRAPHOS_GRAPH` and the fixture fallback, the mnemo tokenised URL, and `dev-stack:fetch`/`dev-stack:check`; verify every command quoted in the section exists in the task or scripts.
- [x] 5.2 Run `openspec status --change devenv-up-stack` (4/4) and `openspec validate devenv-up-stack --strict` (valid), then `devenv tasks run studio:ci` to confirm the Elm build, tests, lint, fixture drift and token lint stay green.
