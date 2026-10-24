# Contributing to nx-complete-fish

Issues and pull requests are welcome. `main` accepts changes only through pull requests with green CI and signed commits.

## Setup

The development tools are pinned in `mise.toml`. mise provides fish only on Linux; on macOS install it with `brew install fish`.

```sh
mise install
mise run hooks       # pre-commit: check and test; commit-msg: Conventional Commits
```

## Checks and tests

```sh
mise run check       # fish_indent, fish --no-execute, ShellCheck, shfmt
mise run test        # tests with the fish on PATH
mise run test:oldest # tests with fish 4.0.0 in Docker (CI: at every release)
mise run smoke       # fisher in a temporary HOME, completion in a new shell
mise run format      # fish_indent and shfmt
```

CI runs `check`, `test` and `smoke` on ubuntu and macOS for every pull request. The tests with the oldest supported fish run in the Release workflow.

## Files

| File | Content |
| --- | --- |
| `functions/__nx_complete.fish` | the completion: hand-over to Nx, generator options, configurations |
| `completions/nx.fish` | the completion rule |
| `tests/nx_completion_test.fish` | everything above in a fake workspace with a fake Nx, through `complete -C` |
| `tests/smoke.sh` | fisher installation in a temporary HOME |

## Commits

Commits follow [Conventional Commits](https://www.conventionalcommits.org) (`feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `ci`), with a subject of at most 72 characters. Mark a breaking change with `!` and a `BREAKING CHANGE:` footer; [Versioning](README.md#versioning) in the README says what counts as breaking.

## Releases

A release takes two steps, because `main` accepts changes only through pull requests:

1. On an up-to-date `main`, run `mise run test:oldest` and then `mise run release:prepare`. git-cliff computes the next version (or pass one, for example `mise run release:prepare v0.2.0`) and writes CHANGELOG.md on the branch `chore/release-vX.Y.Z`; the task commits it, pushes the branch and opens a pull request.
2. After the pull request is merged, run `git switch main && git pull --ff-only && mise run release:tag`. The task creates the signed tag on the release commit and pushes it. The Release workflow then tests the oldest supported fish and, when the tests pass, creates the GitHub Release with the notes of that version. A failure there leaves the tag without a GitHub Release, and the fix needs a new patch version.

```sh
mise run release:prepare # on main: CHANGELOG.md on a release branch and a pull request
mise run release:tag     # on main after that merge: the signed tag vX.Y.Z
```
