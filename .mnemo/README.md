# mnemo in graphos-studio

The project's memory lives in the **`graphos-studio`** space of the mnemo memory
graph (`http://localhost:7477`), shared with every other space and told apart by
the `space` property. The configuration is `~/.config/mnemo/graphos-studio.yaml`;
the wrapper is `mnemo-graphos-studio` (console on `127.0.0.1:7482`).

```bash
mnemo-graphos-studio status
mnemo-graphos-studio doctor
mnemo-graphos-studio web
```

## `openspec-release`

`workflows/openspec-release.yaml` is the proposal-to-release workflow of this
repository. It registers an OpenSpec change (or reuses a complete one), has a
person accept the proposal, creates the worktree in
`<repo>-worktrees/<change>` on `openspec/<change>`, opens the draft pull request
with the proposal, develops and
commits it atomically, reviews it on GitHub, gates on the review and green CI,
archives the change, squash-merges into `main`, bumps the `openspec-view`
version, tags `v<version>` and creates the GitHub release, then removes the
worktree and the branch.

Run it from this checkout, inside `devenv shell`, with the space configuration:

```bash
export MNEMO_CONFIG=$HOME/.config/mnemo/graphos-studio.yaml
mnemo workflow import .mnemo/workflows/openspec-release.yaml
mnemo run openspec-release --param change=my-change --param idea='what to build'
```

The run stops at `accept-proposal` and at `approve-merge` (exit 3); approve each
with `mnemo approve RUN STEP --by NAME` and resume with `mnemo run --resume RUN`.
To start from an existing proposal, pass a change whose `openspec status` is
`4/4`; the proposal step leaves it untouched and you approve the gate once.

The space also carries an `orchestrator` section, so a heartbeat resumes the runs
that wait for no person, from this checkout:

```bash
mnemo-graphos-studio orchestrate --once
```

The first run's branch bootstraps `openspec/`, `.opencode/`, `.mnemo/` and
`scripts/mnemo/` into the pull request when `origin/main` does not hold them yet.
`prepare` sets a repository-local `git user.name` (taken from the last commit)
when the checkout has none, so the commits of the run do not fail.

The mechanical work is in `scripts/mnemo/openspec-release.sh`; the delegate
target `studio-agent` (defined in the space configuration) runs
`scripts/mnemo/agent.sh`, which enters the worktree recorded by the workflow and
then runs `opencode run`.
