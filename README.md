# nx-complete-fish

Tab completion for [Nx](https://nx.dev) in fish: `nx`, `pnpm nx`, `pnpm exec nx` and `npx nx`, also from a subdirectory of the workspace. Commands, projects, targets and generator names come from the Nx of the workspace. The plugin adds the options of generators with their values and the configurations of targets, which Nx does not complete.

For zsh, see [nx-complete-zsh](https://github.com/rapaglaz/nx-complete-zsh).

## What it completes

| You type | You get | Source |
| --- | --- | --- |
| `nx <Tab>` | commands and targets | Nx (`NX_COMPLETE`) |
| `nx build <Tab>`, `nx run <Tab>` | projects, `project:target` | Nx |
| `nx g <Tab>` | generators, for example `@nx/angular:component` | Nx |
| `nx g @nx/angular:component --<Tab>` | the options of the generator, with descriptions | `schema.json` of the generator |
| `nx g @nx/angular:component --style=<Tab>` | `css`, `scss`, `sass`, `less`, `none` | `enum` in `schema.json` |
| `nx g @nx/workspace:move --projectName <Tab>` | the projects of the workspace | `x-dropdown: projects` |
| `nx run app:build:<Tab>` | `app:build:production`, `app:build:development` | project graph |
| `nx build app -c <Tab>`, `--configuration=<Tab>` | the configurations of the target | project graph |
| `nx run-many -t build,test -c <Tab>` | the configurations of these targets in all projects | project graph |
| `pnpm nx ...`, `pnpm exec nx ...`, `npx nx ...` | the same as `nx ...` | |

Other `pnpm` and `npx` commands keep the completion that they have without the plugin, for example the pnpm completion that fish 4.1 and later include. Outside an Nx workspace, `nx <Tab>` completes file names.

## Requirements

- fish 4.0 or later (tested with 4.0.0 and 4.9.3)
- Nx 23.3 or later in the workspace (tested with 23.3.0 and 23.3.1). An older Nx gets file names only, see [How it works](#how-it-works).
- [jq](https://jqlang.org) for the generator options and the configurations

## Installation

### fisher

```fish
fisher install rapaglaz/nx-complete-fish
```

fisher refuses to install the plugin when `~/.config/fish/completions/pnpm.fish` or `npx.fish` already exists, for example from `pnpm completion fish > ~/.config/fish/completions/pnpm.fish`. Move that file to a directory that fish reads later, and the plugin loads it as the pnpm completion:

```fish
mkdir -p ~/.local/share/fish/vendor_completions.d
mv ~/.config/fish/completions/pnpm.fish ~/.local/share/fish/vendor_completions.d/
fisher install rapaglaz/nx-complete-fish
```

The installation with fisher is tested in CI (fisher 4.4.8).

### Manual

```fish
git clone https://github.com/rapaglaz/nx-complete-fish ~/src/nx-complete-fish
cp ~/src/nx-complete-fish/functions/*.fish ~/.config/fish/functions/
cp ~/src/nx-complete-fish/completions/*.fish ~/.config/fish/completions/
```

If you used the fisher plugin `jukben/fish-nx` before, remove it first with `fisher remove jukben/fish-nx`, because it installs its own `completions/nx.fish`.

## How it works

- Nx 23.3 and later complete commands, projects, targets and generator names themselves. On Tab, the plugin runs the Nx of the workspace (`node_modules/.bin/nx` or `.nx/installation/node_modules/.bin/nx`) with `NX_COMPLETE=fish` and shows its answer.
- Before that, the plugin reads the version from `node_modules/nx/package.json` (or looks for `nx/dist/src/command-line/completion`) without starting Node. An older Nx is never started, because it ignores `NX_COMPLETE` and would run the command that you are typing: `nx run app:build` would really build.
- Generator options and their values come from the `schema.json` of the generator: `enum` and `items.enum`, booleans, `x-dropdown: projects`, generator aliases, and local workspace plugins through the `generators` or `schematics` field of their `package.json`. Options with `visible: false` are left out.
- Target configurations come from `.nx/workspace-data/project-graph.json`, which every `nx` command writes.
- Both files are read with `jq`, kept in global variables and read again when their modification time changes.
- fish uses only the first `completions/pnpm.fish` that it finds. The `pnpm.fish` and `npx.fish` of the plugin therefore load the completion that they hide (the next file on `$fish_complete_path`, or the one built into fish) and add a condition to its rules, so that after `pnpm nx` only the Nx candidates are shown.

The plugin defines no key bindings and prints nothing when fish starts; everything is loaded at the first Tab.

## Troubleshooting

- **No projects or configurations.** The project graph does not exist yet, for example in a fresh clone. Run any `nx` command once, for example `pnpm nx show projects`.
- **Only file names after `nx`.** The Nx of the workspace is older than 23.3, or `node_modules` is not installed.
- **`nx <Tab>` does nothing, `pnpm nx <Tab>` works.** fish loads the completion of a command only when the command is on `PATH`, and `nx` usually lives in `node_modules/.bin` of the workspace. Use `pnpm nx`, or put `node_modules/.bin` on `PATH`, for example with [mise](https://mise.jdx.dev) in the `mise.toml` of the workspace:

  ```toml
  [env]
  _.path = ["{{config_root}}/node_modules/.bin"]
  ```

## Development

The development tools are pinned in `mise.toml`. mise provides fish only on Linux; on macOS install it with `brew install fish`.

```sh
mise install
mise run hooks       # pre-commit: check and test; commit-msg: Conventional Commits
mise run check       # fish_indent, fish --no-execute, ShellCheck, shfmt
mise run test        # tests with the fish on PATH
mise run test:oldest # tests with fish 4.0.0 in Docker
mise run smoke       # fisher in a temporary HOME, completion in a new shell
mise run format      # fish_indent and shfmt
```

| File | Content |
| --- | --- |
| `functions/__nx_complete.fish` | the completion: hand-over to Nx, generator options, configurations |
| `functions/__nx_complete_wrap.fish` | loads the hidden pnpm or npx completion and adds the Nx rule |
| `completions/nx.fish`, `pnpm.fish`, `npx.fish` | the completion rules |
| `tests/nx_completion_test.fish` | everything above in a fake workspace with a fake Nx, through `complete -C` |
| `tests/smoke.sh` | fisher installation in a temporary HOME |

Commits follow [Conventional Commits](https://www.conventionalcommits.org) (`feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `ci`), with a subject of at most 72 characters.

## License

[MIT](LICENSE)
