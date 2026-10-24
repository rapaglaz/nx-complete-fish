#!/usr/bin/env bash
#
# Installs the plugin with fisher, the way README.md describes it, into a temporary HOME and
# starts real fish shells: an interactive start must print nothing, and `nx` and `pnpm nx` must
# complete from the Nx of a fake workspace. Needs fish, curl and network access to download fisher.
#
# Usage: bash tests/smoke.sh (or `mise run smoke`)

set -euo pipefail

repo_dir="$(CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fisher_version=4.4.8
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
failed=0

check() { # <description> <expected> <actual>
    if [[ "$3" == "$2" ]]; then
        echo "ok   $1"
    else
        echo "FAIL $1 (expected '$2', got '$3')"
        failed=1
    fi
}

# A workspace with a fake Nx 23.3 that answers NX_COMPLETE with one target. fish loads the
# completion of a command only when it is on PATH, so the workspace binaries are put there.
ws="$home/ws"
mkdir -p "$ws/apps/app" "$ws/node_modules/.bin" "$ws/node_modules/nx" "$home/bin"
echo '{}' >"$ws/nx.json"
echo '{ "name": "nx", "version": "23.3.0" }' >"$ws/node_modules/nx/package.json"
printf '%s\n' '#!/bin/sh' 'printf "build-only\tRun build\n"' >"$ws/node_modules/.bin/nx"
printf '%s\n' '#!/bin/sh' >"$home/bin/pnpm"
chmod +x "$ws/node_modules/.bin/nx" "$home/bin/pnpm"

shell() {
    env -i HOME="$home" TERM=dumb PATH="$ws/node_modules/.bin:$home/bin:$PATH" fish "$@"
}

shell -c "curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/$fisher_version/functions/fisher.fish | source
    and fisher install jorgebucaran/fisher@$fisher_version
    and fisher install '$repo_dir'" >/dev/null

check "fisher installed the plugin" "yes" \
    "$(shell -c "contains -- '$repo_dir' \$_fisher_plugins; and echo yes")"
check "a new interactive shell starts without output" "" "$(shell -i -c exit 2>&1)"
check "nx completes from Nx" "build-only" \
    "$(shell -i -c "cd '$ws/apps/app'; complete -C 'nx bu' | string replace -r '\t.*' ''")"
check "pnpm nx completes from Nx" "build-only" \
    "$(shell -i -c "cd '$ws'; complete -C 'pnpm nx bu' | string replace -r '\t.*' ''")"
check "Tab stays bound to complete" "bind --preset tab complete" \
    "$(shell -i -c "bind tab" 2>&1)"

exit "$failed"
