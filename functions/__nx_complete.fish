# Tab completion for Nx, used by completions/nx.fish, pnpm.fish and npx.fish. Nx 23.3 and later
# complete commands, projects, targets and generator names themselves (Tab runs the workspace-local
# nx with NX_COMPLETE=fish). These functions add what Nx leaves out and read it with jq from the
# workspace: the options of a generator and their values (its schema.json) and the configurations of
# a target (.nx/workspace-data/project-graph.json, which every nx command keeps current).
# Results are cached in global variables for the life of the shell and checked against the file mtime.
#
#   __nx_complete            prints the candidates for the command line
#   __nx_complete --wrapped  true when nx is completed after a runner: `pnpm nx`, `pnpm exec nx`,
#                            `npx nx`, `bunx nx`, `bun nx`, `bun x nx`, `bun run nx`, `npm exec nx`
#                            or `npm exec -- nx`
function __nx_complete
    set -l tokens (commandline -xpc)
    set -l current (commandline -ct)

    # The runner words are dropped, so the rest sees `nx ...` in every case. The completion rules
    # decide which commands are runners; this only counts their words.
    set -l skip 0
    if test "$tokens[2]" = nx
        set skip 1
    else if test "$tokens[3]" = nx; and contains -- "$tokens[2]" exec x run
        set skip 2
    else if test "$tokens[2]" = exec; and test "$tokens[3]" = --; and test "$tokens[4]" = nx
        set skip 3
    end
    if test "$argv[1]" = --wrapped
        test $skip -gt 0 -a (count $tokens) -gt $skip
        return
    end
    test $skip -gt 0; and set -e tokens[1..$skip]

    set -l root (__nx_root)
    or begin
        __fish_complete_path $current
        return
    end
    __nx_complete_generator $root $current $tokens
    or __nx_complete_configuration $root $current $tokens
    or __nx_complete_native $root $current $tokens
end

# The workspace root: the nearest directory with nx.json, so Tab also works in apps/foo.
function __nx_root
    set -l dir $PWD
    while true
        if test -f $dir/nx.json
            echo $dir
            return 0
        end
        test $dir = /; and return 1
        set dir (path dirname -- $dir)
    end
end

# The nx binary of the workspace, but only when that Nx answers NX_COMPLETE: an older Nx ignores the
# variable and would run the command that is being typed. 23.3 is the first version checked to have
# it; the directory of the completion modules covers a version written differently.
function __nx_native_bin --argument-names root
    for base in $root/node_modules $root/.nx/installation/node_modules
        test -x $base/.bin/nx; or continue
        if test -d $base/nx/dist/src/command-line/completion
            echo $base/.bin/nx
            return 0
        end
        test -r $base/nx/package.json; or continue
        # The first "version" key of package.json is the package version.
        string match -rq '"version"\s*:\s*"(?<major>\d+)\.(?<minor>\d+)' <$base/nx/package.json
        or continue
        if test $major[1] -gt 23; or test $major[1] -eq 23 -a $minor[1] -ge 3
            echo $base/.bin/nx
            return 0
        end
    end
    return 1
end

# Reads projects, their roots and the configurations of their targets from the project graph into
# __nx_projects, __nx_project_roots (same order) and __nx_configs (`project<TAB>target<TAB>names`).
function __nx_load_graph --argument-names root
    set -l graph $root/.nx/workspace-data/project-graph.json
    test -f $graph; or return 1
    set -l key $graph:(path mtime -- $graph)
    test "$__nx_graph_key" = $key; and return 0

    set -g __nx_projects
    set -g __nx_project_roots
    set -g __nx_configs
    # Older graph files wrap the nodes in .graph.
    for line in (jq -r '
            (.graph.nodes // .nodes // {})[] | .name as $p
            | "P\t\($p)\t\(.data.root // "")",
              (.data.targets // {} | to_entries[] | select((.value.configurations // {}) | length > 0)
                | "C\t\($p)\t\(.key)\t\(.value.configurations | keys | join(" "))")
        ' $graph 2>/dev/null)
        set -l fields (string split \t -- $line)
        switch $fields[1]
            case P
                set -a __nx_projects $fields[2]
                set -a __nx_project_roots $fields[3]
            case C
                set -a __nx_configs (string join \t -- $fields[2..4])
        end
    end
    set -g __nx_graph_key $key
end

# The configurations of a target in one project or, without a project, in all of them.
function __nx_configurations --argument-names target project
    set -l found
    for line in $__nx_configs
        set -l fields (string split \t -- $line)
        test "$fields[2]" = $target; or continue
        test -z "$project"; or test "$fields[1]" = "$project"; or continue
        for name in (string split ' ' -- $fields[3])
            contains -- $name $found; or set -a found $name
        end
    end
    string join \n -- $found
    test (count $found) -gt 0
end

# The schema.json of a generator such as @nx/angular:component or its alias @nx/angular:c. The
# collection is an installed package or a local plugin of the workspace.
function __nx_generator_schema --argument-names root spec
    string match -qr '^(?<collection>[^:]+):(?<name>.+)$' -- $spec; or return 1
    set -l cache __nx_schema_path_(string escape --style=var -- $root:$spec)
    if set -q $cache; and test -f $$cache
        echo $$cache
        return 0
    end

    set -l manifest $root/node_modules/$collection/package.json
    if not test -f $manifest; and __nx_load_graph $root
        set -l candidates
        for dir in $__nx_project_roots
            test -f $root/$dir/package.json; and set -a candidates $root/$dir/package.json
        end
        test (count $candidates) -gt 0; or return 1
        set manifest (jq -r --arg c $collection 'select(.name == $c) | input_filename' $candidates 2>/dev/null)[1]
    end
    test -f "$manifest"; or return 1

    set -l file (jq -r '.generators // .schematics // empty' $manifest 2>/dev/null)
    test -n "$file"; or return 1
    set file (path dirname -- $manifest)/$file
    test -f $file; or return 1
    set -l schema (jq -r --arg n $name '
            first((.generators // {}) + (.schematics // {}) | to_entries[]
              | select(.key == $n or ((.value.aliases // []) | index($n) != null)) | .value.schema) // empty
        ' $file 2>/dev/null)
    test -n "$schema"; or return 1
    set schema (path dirname -- $file)/$schema
    test -f $schema; or return 1
    set -g $cache $schema
    echo $schema
end

# One `name<TAB>kind<TAB>values<TAB>description` line per visible option of a schema; kind is
# projects, enum (values lists them), boolean or value.
function __nx_schema_options --argument-names schema
    set -l cache __nx_schema_(string escape --style=var -- $schema)
    set -l mtime (path mtime -- $schema); or return 1
    set -l mtime_cache {$cache}_mtime
    if test "$$mtime_cache" != $mtime
        set -g $cache (jq -r '
                .properties // {} | to_entries[] | select(.value.visible != false and .value.hidden != true)
                | (.value.enum // .value.items.enum) as $enum
                | [ .key,
                    (if .value."x-dropdown" == "projects" then "projects"
                     elif $enum then "enum"
                     elif .value.type == "boolean" then "boolean"
                     else "value" end),
                    (($enum // []) | map(tostring) | join(" ")),
                    ((.value.description // "") | gsub("[[:space:]]+"; " ")) ]
                | join("\t")
            ' $schema 2>/dev/null)
        set -g $mtime_cache $mtime
    end
    string join \n -- $$cache
    test (count $$cache) -gt 0
end

# The values of a generator option, each after a prefix (`--style=` or nothing); free text gets
# file names, like Nx does.
function __nx_option_values --argument-names root kind values prefix current
    set -l found
    switch $kind
        case projects
            __nx_load_graph $root; and set found $__nx_projects
        case enum
            set found (string split ' ' -- $values)
        case boolean
            set found true false
    end
    if test (count $found) -gt 0
        printf "$prefix%s\n" $found
    else if test -n "$prefix"
        __fish_complete_path (string replace -- $prefix '' $current) | string replace -r -- '^' $prefix
    else
        __fish_complete_path $current
    end
end

# nx g <collection:generator> ...: the options of the generator and their values. Returns 1 for
# everything else (the generator name, positional arguments), which Nx completes.
function __nx_complete_generator --argument-names root current
    set -l tokens $argv[3..]
    contains -- "$tokens[2]" g generate; or return 1
    set -l spec
    for token in $tokens[3..]
        if not string match -q -- '-*' $token
            set spec $token
            break
        end
    end
    test -n "$spec"; or return 1
    set -l schema (__nx_generator_schema $root $spec); or return 1
    set -l options (__nx_schema_options $schema); or return 1

    set -l name
    set -l prefix
    if string match -qr -- '^--(?<option>[^=]+)=' $current
        set name $option
        set prefix --$option=
    else if string match -qr -- '^--(?<option>.+)$' "$tokens[-1]"; and not string match -q -- '-*' $current
        set name $option
    end
    if test -n "$name"
        for line in $options
            set -l fields (string split \t -- $line)
            test $fields[1] = $name; or continue
            # A boolean option takes no value after a space: the word is positional.
            test -z "$prefix"; and test $fields[2] = boolean; and return 1
            __nx_option_values $root $fields[2] "$fields[3]" "$prefix" $current
            return 0
        end
        test -n "$prefix"; and return 1
    end
    string match -q -- '-*' $current; or return 1

    for line in $options
        set -l fields (string split \t -- $line)
        printf '%s\t%s\n' --$fields[1] $fields[4]
    end
    # The flags of `nx generate` itself, as `nx g --help` lists them in Nx 23.
    printf '%s\n' \
        --dry-run\t'Preview the changes without updating files.' \
        --interactive\t'When false disables interactive input prompts for options.' \
        --quiet\t'Hides logs from tree operations.' \
        --verbose\t'Prints additional information about the commands.' \
        --help\t'Show help'
end

# Configurations: `nx run project:target:<Tab>` and the value of -c / --configuration after
# `nx run`, `nx <target> [project]`, `nx run-many` and `nx affected`.
function __nx_complete_configuration --argument-names root current
    set -l tokens $argv[3..]
    if test "$tokens[2]" = run; and test (count $tokens) -eq 2
        and string match -qr -- '^(?<project>[^:]+):(?<target>[^:]+):' $current
        __nx_load_graph $root; or return 0
        for name in (__nx_configurations $target $project)
            printf '%s:%s:%s\n' $project $target $name
        end
        return 0
    end

    contains -- "$tokens[2]" g generate; and return 1
    set -l prefix
    if string match -q -- '--configuration=*' $current
        set prefix --configuration=
    else if not contains -- "$tokens[-1]" -c --configuration
        return 1
    end

    set -l targets
    set -l project
    switch "$tokens[2]"
        case run
            string match -qr '^(?<run_project>[^:]+):(?<run_target>[^:]+)' -- "$tokens[3]"
            and set project $run_project
            and set targets $run_target
        case run-many affected
            for i in (seq 3 (count $tokens))
                switch $tokens[$i]
                    case -t --targets --target
                        set -l next (math $i + 1)
                        test $next -le (count $tokens); and set -a targets (string split , -- $tokens[$next])
                    case '-t=*' '--targets=*' '--target=*'
                        set -a targets (string split , -- (string replace -r '^[^=]*=' '' -- $tokens[$i]))
                end
            end
        case '*'
            set targets $tokens[2]
            if test (count $tokens) -ge 3; and not string match -q -- '-*' $tokens[3]
                set project $tokens[3]
            end
    end

    __nx_load_graph $root; or return 0
    set -l found
    for target in $targets
        for name in (__nx_configurations $target $project)
            contains -- $name $found; or set -a found $name
        end
    end
    test (count $found) -gt 0; and printf "$prefix%s\n" $found
    return 0
end

# Everything else comes from Nx; an older Nx or a workspace without node_modules gets file names.
function __nx_complete_native --argument-names root current
    set -l tokens $argv[3..]
    set -l nx (__nx_native_bin $root)
    or begin
        __fish_complete_path $current
        return
    end
    # Nx prints `value<TAB>description` lines, the format that fish expects.
    set -l output (NX_COMPLETE=fish $nx nx $tokens[2..] "$current" 2>/dev/null)
    if test (count $output) -gt 0
        printf '%s\n' $output
    else
        __fish_complete_path $current
    end
end
