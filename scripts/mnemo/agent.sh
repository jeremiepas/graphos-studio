#!/usr/bin/env bash
#
# The delegate target of the graphos-studio space (`studio-agent`).
#
# mnemo gives the card on standard input. The proposal step runs in the main
# checkout; the development and review steps must run in the worktree recorded
# by `openspec-release.sh worktree`, so this wrapper enters it when it exists.
# The model is the one the space config names.

set -euo pipefail

STATE="$(git rev-parse --absolute-git-dir)/mnemo/openspec-release.state"

if [[ -f "${STATE}" ]]; then
  TREE="$(sed -n 's/^worktree=//p' "${STATE}" | head -1)"
  if [[ -n "${TREE}" && -d "${TREE}" ]]; then
    cd "${TREE}"
  fi
fi

exec opencode run --auto --model "${MNEMO_STUDIO_MODEL:-litellm/ollama-cloud/deepseek-v4.1-flash}"
