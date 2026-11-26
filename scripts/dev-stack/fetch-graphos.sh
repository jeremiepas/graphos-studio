#!/usr/bin/env bash
# Fetch and verify the pinned Graphos release binary, then exit without
# running it. `graphos.sh` calls this first; `dev-stack:fetch` runs it ahead of
# time so a first `devenv up` does not have to download 100+ MB.
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

require_linux_x86_64

version="$(pin '.graphos.version')"
repo="$(pin '.graphos.repo')"
asset="$(pin '.graphos.asset')"
expected="$(pin '.graphos.sha256')"

artifact_dir="$ARTIFACTS_DIR/graphos/$version"
artifact="$artifact_dir/graphos"
sidecar="$artifact_dir/graphos.sha256"

# Reuse a verified artifact without touching the network. A cached file that
# no longer matches the pin is evicted and the run fails: there is no insecure
# path that starts it anyway (design decision 8).
if [ -f "$artifact" ]; then
  if hash_matches "$artifact" "$expected"; then
    printf '%s  graphos\n' "$expected" > "$sidecar"
    link_artifact "$artifact" graphos
    note "graphos $version is verified in the cache ($artifact)"
    exit 0
  fi
  actual="$(sha256_of "$artifact")"
  rm -f -- "$artifact" "$sidecar"
  die "cached graphos $version has SHA-256 $actual, the pin is $expected; artifact removed, rerun devenv tasks run dev-stack:fetch"
fi

mkdir -p -- "$artifact_dir"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

url="https://github.com/$repo/releases/download/$version/$asset"
note "fetching $url"
curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/$asset" "$url" \
  || die "could not download $url; check the network, then rerun devenv tasks run dev-stack:fetch"
note "fetching $url.sha256"
curl -fsSL --retry 3 --retry-delay 2 -o "$tmp/$asset.sha256" "$url.sha256" \
  || die "could not download the published checksum $url.sha256; refusing to run an unverified binary"

published="$(awk 'NR == 1 {print $1}' "$tmp/$asset.sha256")"
[ "$published" = "$expected" ] \
  || die "published SHA-256 $published differs from the pin $expected in $PINS_FILE"

verify_pinned_sha256 "$tmp/$asset" "$published" "downloaded graphos $version"

chmod 0755 -- "$tmp/$asset"
mv -- "$tmp/$asset" "$artifact"
printf '%s  graphos\n' "$published" > "$sidecar"
link_artifact "$artifact" graphos
note "graphos $version verified and cached at $artifact"
