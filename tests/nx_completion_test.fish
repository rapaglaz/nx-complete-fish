# Tests the Nx completion (functions/ and completions/) in a fake workspace: generator options and
# values from schema.json, target configurations from the project graph, the hand-over to
# NX_COMPLETE, the cache refresh, and the pnpm and npx wrappers together with the completion that
# pnpm has without this plugin. `complete -C` runs the real completion engine, so no terminal is
# needed.
# Usage: fish --no-config tests/nx_completion_test.fish (or `mise run test`)

set -l repo (path resolve (status dirname)/..)
set -p fish_function_path $repo/functions
set -p fish_complete_path $repo/completions

command -q jq; or begin
    echo "FAIL jq is missing"
    exit 1
end

set -g root (mktemp -d)
set -l ws $root/ws
set -g failed 0

mkdir -p $ws/.nx/workspace-data $ws/apps/app/src $ws/tools/gen \
    $ws/node_modules/@acme/plugin/component $ws/node_modules/.bin \
    $ws/node_modules/nx/dist/src/command-line/completion
echo '{}' >$ws/nx.json

function write_graph --argument-names ws stamp configs
    printf '%s\n' '{ "nodes": {' \
        '"app": { "name": "app", "data": { "root": "apps/app", "targets": {' \
        "  \"build\": { \"configurations\": { $configs } }, \"serve\": {} } } }," \
        '"lib": { "name": "lib", "data": { "root": "libs/lib", "targets": {' \
        '  "build": { "configurations": { "production": {}, "ci": {} } } } } },' \
        '"gen": { "name": "gen", "data": { "root": "tools/gen", "targets": {} } }' \
        '} }' >$ws/.nx/workspace-data/project-graph.json
    touch -t $stamp $ws/.nx/workspace-data/project-graph.json
end
write_graph $ws 202001010000 '"development": {}, "production": {}'

echo '{ "name": "@acme/plugin", "generators": "./generators.json" }' >$ws/node_modules/@acme/plugin/package.json
echo '{ "generators": { "component": { "schema": "./component/schema.json", "aliases": ["c"] } } }' >$ws/node_modules/@acme/plugin/generators.json
printf '%s\n' '{ "properties": {' \
    '"style": { "type": "string", "enum": ["css", "scss"], "description": "The\nstyle." },' \
    '"project": { "type": "string", "x-dropdown": "projects" },' \
    '"skipTests": { "type": "boolean" },' \
    '"name": { "type": "string" },' \
    '"secret": { "type": "string", "visible": false }' \
    '} }' >$ws/node_modules/@acme/plugin/component/schema.json
# A local plugin: a project of the graph whose package.json names a collection.
echo '{ "name": "@local/gen", "schematics": "./collection.json" }' >$ws/tools/gen/package.json
echo '{ "schematics": { "thing": { "schema": "./thing.json" } } }' >$ws/tools/gen/collection.json
echo '{ "properties": { "flavor": { "type": "string" } } }' >$ws/tools/gen/thing.json

# Fake Nx 23: records what it was called with and answers like NX_COMPLETE does.
printf '%s\n' '#!/bin/sh' \
    "printf '%s|' \"\${NX_COMPLETE:-none}\" \"\$@\" >\"$root/nx-call\"" \
    "printf 'build\\tRun build\\napp:\\n'" >$ws/node_modules/.bin/nx
chmod +x $ws/node_modules/.bin/nx
# fish loads completions/nx.fish only for a command on PATH; mise puts node_modules/.bin there.
set -p PATH $ws/node_modules/.bin

# Fake pnpm and npx, so that no real one runs. The fake pnpm prints a completion script like
# `pnpm completion fish` does; the completion built into fish 4.1 and later sources it.
mkdir -p $root/bin $root/later
printf '%s\n' '#!/bin/sh' 'echo "complete -c pnpm -f -a BUILTIN-install"' >$root/bin/pnpm
printf '%s\n' '#!/bin/sh' >$root/bin/npx
chmod +x $root/bin/pnpm $root/bin/npx
set -p PATH $root/bin
set -gx XDG_CACHE_HOME $root/cache
# A pnpm completion that this plugin hides: a later directory of $fish_complete_path.
echo 'complete -c pnpm -f -a "ORIG-install ORIG-nx"' >$root/later/pnpm.fish
set -a fish_complete_path $root/later

# The candidates of a command line without descriptions, joined with spaces.
function candidates
    complete -C "$argv[1]" | string replace -r '\t.*' '' | string join ' '
end

function check --argument-names description expected actual
    if test "$actual" = "$expected"
        echo "ok   $description"
    else
        echo "FAIL $description (expected '$expected', got '$actual')"
        set -g failed 1
    end
end

cd $ws/apps/app/src

set -l out (candidates 'nx g @acme/plugin:component --')
for option in --style --project --skipTests --name --dry-run --interactive --quiet --verbose --help
    contains -- $option (string split ' ' -- $out)
    or check "generator option $option is offered" yes no
end
check "generator options from schema.json, plus the flags of nx generate" 9 (count (string split ' ' -- $out))
check "options with visible: false are left out" 0 (count (string match -- '*secret*' $out))
check "the description of an option is on one line" 'The style.' \
    (complete -C 'nx g @acme/plugin:component --sty' | string replace -r '^[^\t]*\t' '')
check "enum values after --style=, via an alias of the generator" '--style=css --style=scss' \
    (candidates 'nx generate @acme/plugin:c --style=')
check "x-dropdown projects after --project" 'app gen lib' (candidates 'nx g @acme/plugin:component --project ')
check "generator of a local plugin (schematics field)" '--dry-run --flavor --help --interactive --quiet --verbose' \
    (candidates 'nx g @local/gen:thing --')

check "nx run project:target:<Tab> lists configurations" 'app:build:development app:build:production' \
    (candidates 'nx run app:build:')
check "-c after nx <target> <project>" 'ci production' (candidates 'nx build lib -c ')
check "--configuration= after nx run" '--configuration=development --configuration=production' \
    (candidates 'nx run app:build --configuration=')
check "-c after run-many -t: configurations of all projects" 'ci development production' \
    (candidates 'nx run-many -t build,serve -c ')

rm -f $root/nx-call
check "other positions go to Nx" build (candidates 'nx b')
check "Nx gets NX_COMPLETE=fish and the words up to the cursor" 'fish|nx|b|' (cat $root/nx-call)
check "nx g <Tab> (generator names) goes to Nx" 'app: build' (candidates 'nx g ')

check "pnpm nx completes like nx" 'app:build:development app:build:production' \
    (candidates 'pnpm nx run app:build:')
check "pnpm exec nx completes like nx" 'ci production' (candidates 'pnpm exec nx build lib -c ')
check "npx nx completes like nx" build (candidates 'npx nx b')
rm -f $root/nx-call
complete -C 'pnpm install ' >/dev/null
check "other pnpm commands do not call Nx" no (test -e $root/nx-call; and echo yes; or echo no)
check "the hidden pnpm completion of a later directory still works" 'ORIG-install ORIG-nx' (candidates 'pnpm ')
check "after pnpm nx only Nx candidates are offered" 'app: build' (candidates 'pnpm nx ')
check "npx without a completion of its own offers nothing extra" '' (candidates 'npx --no-such-')

# The completion of pnpm that fish 4.1 and later have built in, in a shell without the later
# directory. It wins over one generated from man pages, as it does in fish itself.
mkdir -p $root/generated_completions
echo 'complete -c pnpm -f -a GENERATED' >$root/generated_completions/pnpm.fish
if status get-file completions/pnpm.fish >/dev/null 2>&1
    set -l builtin (fish --no-config -c "
        set -p fish_function_path $repo/functions
        set -p fish_complete_path $repo/completions
        set -a fish_complete_path $root/generated_completions
        set -p PATH $root/bin
        cd $ws
        complete -C 'pnpm ' | string join ' '
        complete -C 'pnpm nx ' | string replace -r '\t.*' '' | string join ' '")
    check "the built-in pnpm completion still works" BUILTIN-install "$builtin[1]"
    check "after pnpm nx the built-in pnpm completion is silent" 'app: build' "$builtin[2]"
else
    echo "skip the built-in pnpm completion (fish "(string split -f 3 ' ' -- (fish --version))" has none)"
end

# Newer graph: the cached configurations are replaced in the same shell.
write_graph $ws 202101010000 '"staging": {}'
check "a newer project graph refreshes the cache" 'app:build:staging' (candidates 'nx run app:build:')

rm -rf $ws/node_modules/nx/dist
echo '{ "name": "nx", "version": "24.0.1", "dependencies": { "x": { "version": "1.0.0" } } }' >$ws/node_modules/nx/package.json
check "Nx 24 is recognized by its version when the modules moved" build (candidates 'nx b')

echo '{ "name": "nx", "version": "23.2.9" }' >$ws/node_modules/nx/package.json
rm -f $root/nx-call
complete -C 'nx build ' >/dev/null
check "an Nx without NX_COMPLETE is not run" no (test -e $root/nx-call; and echo yes; or echo no)

cd $root
rm -f $root/nx-call
complete -C 'nx ' >/dev/null
check "outside a workspace Nx is not run" no (test -e $root/nx-call; and echo yes; or echo no)

rm -rf $root
exit $failed
