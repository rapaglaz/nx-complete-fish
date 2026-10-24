#!/usr/bin/env bash
#
# Runs the tests (tests/*_test.fish) with the fish on PATH, or with an older fish in a Debian
# container when a version is given, so that the oldest supported release is tested. The release
# is downloaded once into a cache directory, together with the Linux build of jq.
#
# Usage: bash scripts/test.sh [fish version, for example 4.0.0]

set -euo pipefail

# An empty CDPATH keeps cd from searching it and printing the directory.
CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.."

fish_version="${1:-}"
jq_version=1.8.2

if [[ -z "$fish_version" ]]; then
    failed=0
    for test in tests/*_test.fish; do
        echo "==> $test ($(fish --version))"
        fish --no-config "$test" || failed=1
    done
    exit "$failed"
fi

cache="${XDG_CACHE_HOME:-$HOME/.cache}/nx-complete-fish"
fish_dir="$cache/fish-$fish_version"
mkdir -p "$cache"

download() { # <url> <file>
    [[ -s "$2" ]] || curl -fsSL -o "$2" "$1"
}

jq_bin="$cache/jq-$jq_version-linux-amd64"
download "https://github.com/jqlang/jq/releases/download/jq-$jq_version/jq-linux-amd64" "$jq_bin"
chmod +x "$jq_bin"

mounts=()
if [[ ! -x "$fish_dir/fish" ]]; then
    mkdir -p "$fish_dir"
    url="https://github.com/fish-shell/fish-shell/releases/download/$fish_version"
    # Up to 4.0.x the Linux release is a static binary; later releases are named after the platform.
    if [[ "$fish_version" == 4.0.* ]]; then
        download "$url/fish-static-amd64-$fish_version.tar.xz" "$cache/fish-$fish_version-linux.tar.xz"
    else
        download "$url/fish-$fish_version-linux-x86_64.tar.xz" "$cache/fish-$fish_version-linux.tar.xz"
    fi
    tar -xJf "$cache/fish-$fish_version-linux.tar.xz" -C "$fish_dir"
fi
# The static 4.0.x binary looks for its functions and completions in this directory and only
# offers to fill it with `fish --install`; the share directory of the same release has them.
if [[ "$fish_version" == 4.0.* ]]; then
    if [[ ! -d "$fish_dir/share" ]]; then
        download "https://github.com/fish-shell/fish-shell/releases/download/$fish_version/fish-$fish_version.tar.xz" \
            "$cache/fish-$fish_version-src.tar.xz"
        tar -xJf "$cache/fish-$fish_version-src.tar.xz" -C "$fish_dir" --strip-components 1 "fish-$fish_version/share"
    fi
    mounts+=(-v "$fish_dir/share:/root/.local/share/fish/install:ro")
fi

docker run --rm --platform linux/amd64 \
    -v "$PWD:/repo:ro" -v "$fish_dir/fish:/usr/local/bin/fish:ro" -v "$jq_bin:/usr/local/bin/jq:ro" \
    "${mounts[@]}" -w /repo debian:stable-slim \
    sh -c 'status=0; for test in tests/*_test.fish; do echo "==> $test ($(fish --version))"; fish --no-config "$test" || status=1; done; exit $status'
