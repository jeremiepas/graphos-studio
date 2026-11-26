#!/usr/bin/env bash
# Build and record the mnemo binary from the pinned poc-graphos commit, then
# exit without running it. The binary is built once per pin into the local
# cache and verified against its sidecar on every later run.
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

repo="$(pin '.mnemo.repo')"
rev="$(pin '.mnemo.rev')"
subdir="$(pin '.mnemo.subdir')"
version="$(pin '.mnemo.version')"

artifact_dir="$ARTIFACTS_DIR/mnemo/$rev"
artifact="$artifact_dir/mnemo"
sidecar="$artifact_dir/mnemo.sha256"

# Reuse a verified build. Corruption removes the artifact and fails closed.
if [ -f "$artifact" ]; then
  verify_sidecar "$artifact" "$sidecar" "cached mnemo $rev"
  link_artifact "$artifact" mnemo
  note "mnemo $version ($rev) is verified in the cache ($artifact)"
  exit 0
fi

mkdir -p -- "$artifact_dir" "$SRC_DIR"

if [ -n "${MNEMO_SRC:-}" ]; then
  src_root="$MNEMO_SRC"
  [ -d "$src_root/.git" ] \
    || die "MNEMO_SRC=$MNEMO_SRC is not a git checkout of $repo"
  head="$(git -C "$src_root" rev-parse HEAD)"
  [ "$head" = "$rev" ] \
    || die "MNEMO_SRC=$MNEMO_SRC is at $head, the pin is $rev; check out the pinned revision or unset MNEMO_SRC"
else
  src_root="$SRC_DIR/poc-graphos-$rev"
  if [ ! -d "$src_root/.git" ]; then
    note "cloning $repo (uses the authenticated gh CLI; run 'gh auth login' if this fails)"
    gh repo clone "$repo" "$src_root" \
      || die "could not clone $repo; run gh auth login or set MNEMO_SRC to an existing checkout at $rev"
  fi
  git -C "$src_root" fetch --quiet --tags origin \
    || note "could not refresh $repo; using the existing checkout"
  git -C "$src_root" checkout --quiet --detach "$rev" \
    || die "$repo does not contain the pinned revision $rev"
  head="$(git -C "$src_root" rev-parse HEAD)"
  [ "$head" = "$rev" ] \
    || die "checkout $src_root is at $head, the pin is $rev"
fi

mnemo_dir="$src_root/$subdir"
[ -f "$mnemo_dir/mnemo.cabal" ] \
  || die "no mnemo package at $mnemo_dir (pin subdir: $subdir)"

if [ ! -d "$HOME/.cabal/packages" ]; then
  note "cabal package index absent; running cabal update"
  cabal update
fi

note "building mnemo $version from $rev with $(ghc --version)"
(
  cd "$mnemo_dir"
  cabal build exe:mnemo
) || die "cabal build exe:mnemo failed in $mnemo_dir"

built="$(cd "$mnemo_dir" && cabal list-bin exe:mnemo)"
[ -x "$built" ] \
  || die "cabal list-bin exe:mnemo did not return an executable (got: $built)"

tmp="$artifact_dir/.mnemo.$$"
cp -- "$built" "$tmp"
hash="$(sha256_of "$tmp")"
mv -- "$tmp" "$artifact"
printf '%s  mnemo\n' "$hash" > "$sidecar"
link_artifact "$artifact" mnemo
note "mnemo $version built from $rev, SHA-256 $hash, cached at $artifact"
