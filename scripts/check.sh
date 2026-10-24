#!/usr/bin/env bash
#
# Lint and format check, shared by CI, the pre-commit hook and `mise run check`: fish_indent and
# a syntax check (fish --no-execute) for the fish files, ShellCheck and shfmt for the Bash
# scripts. With --write, fish_indent and shfmt format the files instead.
#
# Usage: bash scripts/check.sh [--write]

set -uo pipefail

# An empty CDPATH keeps cd from searching it and printing the directory.
CDPATH='' cd -- "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

fish_files=(functions/*.fish completions/*.fish tests/*.fish)
bash_files=(scripts/*.sh tests/*.sh)
# Four spaces and indented case branches, the same indent as fish_indent uses.
shfmt_flags=(-i 4 -ci)

# fish 4 is one binary that works as fish_indent when it is started under that name. The Linux
# release (and so mise) ships only `fish`, so a temporary link provides the name.
if ! command -v fish_indent >/dev/null 2>&1; then
    link_dir="$(mktemp -d)"
    trap 'rm -rf "$link_dir"' EXIT
    ln -s "$(command -v fish)" "$link_dir/fish_indent"
    PATH="$link_dir:$PATH"
fi

if [[ "${1:-}" == --write ]]; then
    fish_indent --write "${fish_files[@]}"
    shfmt "${shfmt_flags[@]}" -w "${bash_files[@]}"
    exit
fi

failed=0

step() {
    local title="$1"
    shift
    echo "==> ${title}"
    if ! "$@"; then
        echo "FAILED: ${title}" >&2
        failed=1
    fi
}

# shellcheck disable=SC2329 # called through step
fish_syntax() {
    local file status=0
    # fish --no-execute checks only its first argument, so each file gets its own run.
    for file in "${fish_files[@]}"; do
        fish --no-config --no-execute "$file" || status=1
    done
    return "$status"
}

step "fish_indent" fish_indent --check "${fish_files[@]}"
step "fish syntax" fish_syntax
step "bash syntax" bash -n "${bash_files[@]}"
step "shellcheck" shellcheck -x -S style "${bash_files[@]}"
step "shfmt" shfmt "${shfmt_flags[@]}" -d "${bash_files[@]}"

exit "$failed"
