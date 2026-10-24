# nx-complete-fish

Tab completion for [Nx](https://nx.dev) in fish: `nx`, also from a subdirectory of the workspace. Commands, projects, targets and generator names come from the Nx of the workspace. The plugin adds the options of generators with their values and the configurations of targets, which Nx does not complete.

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

Outside an Nx workspace, `nx <Tab>` completes file names.

The plugin completes the command `nx` only, like the completion script of Nx itself. fish loads that completion only when `nx` is on `PATH`, so put `node_modules/.bin` of the workspace on `PATH` (see [Troubleshooting](#troubleshooting)). Since 0.2.0 the plugin does not install rules for `pnpm` and `npx` any more; `pnpm exec nx` and `npx nx` complete when the fish configuration hands the rest of the line over with `__fish_complete_subcommand` (`complete -C`), because `commandline` then returns `nx ...`.

## Requirements

- fish 4.0 or later (tested with 4.9.3 in every CI run, and with 4.0.0 before every release)
- Nx 23.3 or later in the workspace (tested with 23.3.0 and 23.3.1). An older Nx gets file names only, see [How it works](#how-it-works).
- [jq](https://jqlang.org) for the generator options and the configurations

## Installation

### fisher

```fish
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

The plugin defines no key bindings and prints nothing when fish starts; everything is loaded at the first Tab.

## Troubleshooting

- **No projects or configurations.** The project graph does not exist yet, for example in a fresh clone. Run any `nx` command once, for example `pnpm nx show projects`.
- **Only file names after `nx`.** The Nx of the workspace is older than 23.3, or `node_modules` is not installed.
- **`nx <Tab>` does nothing.** fish loads the completion of a command only when the command is on `PATH`, and `nx` usually lives in `node_modules/.bin` of the workspace. Put `node_modules/.bin` on `PATH`, for example with [mise](https://mise.jdx.dev) in the `mise.toml` of the workspace:

  ```toml
  [env]
  _.path = ["{{config_root}}/node_modules/.bin"]
  ```

## Versioning

Releases are Git tags `vX.Y.Z` that follow [Semantic Versioning](https://semver.org), with the changes in [CHANGELOG.md](CHANGELOG.md). While the version is 0.x, a breaking change raises the minor version. To stay on one version, install its tag: `fisher install rapaglaz/nx-complete-fish@v0.1.0`.

A change is breaking when it raises a minimum version (Nx, the shell or jq), changes how the plugin is installed, or renames or removes the function `__nx_complete` or the file `completions/nx.fish`. Other names that start with `__nx_`, for example the caches, are internal and can change in any release.

## Contributing

The development setup, the tests, the commit rules and the release steps are in [CONTRIBUTING.md](CONTRIBUTING.md). Instructions for AI coding agents are in [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE)
