# Instructions for AI coding agents

Tab completion for `nx` in fish, published as a fisher plugin. `README.md` describes what the plugin completes and how it works; `CONTRIBUTING.md` has the setup, the tasks and the release steps; this file covers how to change it safely. The plugin runs on every Tab in other people's shells, so a mistake breaks their completion or, worse, runs an Nx command.

## Commands

- `mise run check` runs `fish_indent --check` and `fish --no-execute` (once per file) on the fish files and ShellCheck (0.11.0, pinned) and shfmt on the Bash scripts. The pre-commit hook runs it together with `mise run test`.
- `mise run test` runs `tests/*_test.fish` with `fish --no-config`; the tests use `complete -C`, the real completion engine, so no terminal is needed.
- `mise run test:oldest` runs the same tests with fish 4.0.0 in a Debian container. Run it after a change to `functions/` or `completions/`, because CI runs it only at a release.
- `mise run smoke` installs the plugin with fisher in a temporary `HOME` and completes in a new shell (needs network).

## Scope

- The plugin completes the command `nx` only. It does not install rules for `pnpm`, `npx` or other runners: since 0.2.0 that belongs in the fish configuration, which hands the rest of the line over with `__fish_complete_subcommand`. `__nx_complete` works there because `commandline` inside a nested `complete -C` returns that line. Do not add runner files back: a `completions/pnpm.fish` of the plugin would hide the pnpm completion that fish ships, and fisher refuses to install over a file of the same name in the user's configuration.
- `functions/__nx_complete.fish` holds the completion; `completions/nx.fish` has the only rule.
- Public names are `__nx_complete` and `completions/nx.fish`. Renaming or removing them, raising a minimum version (fish 4.0, Nx 23.3, jq) or changing the installation is a breaking change (`!` and a `BREAKING CHANGE:` footer). Other `__nx_*` names are internal.

## Conventions

- Comments, names, commit messages, README and PR text are in English. Comments explain why, not what.
- fish files are formatted with `fish_indent` (4 spaces); Bash scripts under `scripts/` and `tests/` use 4 spaces (`shfmt -i 4 -ci`).
- Conventional Commits with `feat`, `fix`, `chore`, `refactor`, `test`, `docs` and `ci`, subject at most 72 characters; the `commit-msg` hook checks it. Commits and tags are GPG-signed.
- Do not add lint rules, plugins or MCP servers without asking.

## Git workflow

- Branch `type/short-description` -> commit -> pull request. `main` accepts only pull requests with green CI and signed commits; never push to it or force-push it.
- Releases go through `mise run release:prepare` and, after that pull request is merged, `mise run release:tag` (see `CONTRIBUTING.md`). fisher installs the latest commit of `main` unless the user pins a tag with `@vX.Y.Z`, so everything merged to `main` reaches users at their next `fisher update`.
- Pushing, opening a pull request and creating a release are visible to others: confirm with the owner first unless the task already asked for it. Check that a pull request is still open before pushing to its branch; a push to the branch of a merged pull request creates the deleted branch again.

## Things that are easy to get wrong

- An Nx older than 23.3 ignores `NX_COMPLETE` and would run the command that is being typed (`nx run app:build` would build). `__nx_native_bin` reads the version from `node_modules/nx/package.json` without starting Node; never call an Nx binary before that check passes, and never take `nx` from `PATH` instead of the workspace.
- fish loads `completions/<command>.fish` only for a command on `PATH`. A completion test must put a fake binary there.
- When `fish_complete_path` changes, or a completion file changes on disk, fish loads the completion again and drops all rules of the command first. In a test, change `fish_complete_path` before the first `complete -C`.
- In single quotes fish still turns `\\` into `\`, so a jq regex written as `"\\s"` reaches jq as `"\s"`; use `[[:space:]]`.
- The `printf` builtin takes the first argument as the format even when it is `--`. An empty list disappears from the argument list, so `printf '%s%s\t%s\n' $prefix $value ...` shifts the values when `$prefix` is empty; quote it.
- `test a = b -a c = d` breaks when a value starts with `-`; write `test ...; and test ...`. `$list[N]` out of range is an error, `set -e list[1..0]` is a reversed range, and `(...)` inside double quotes is not a command substitution (`"$tokens[(math ...)]"` is an invalid index).
- A new interactive shell must start without any output, and the plugin must not bind keys.
