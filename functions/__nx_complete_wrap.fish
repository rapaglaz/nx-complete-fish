# Gives `<command> nx ...` the Nx completion and keeps the completion that the command has without
# this plugin. fish loads only the first completions/<command>.fish on $fish_complete_path, so this
# file would hide the completion of pnpm that fish 4.1 and later ship, or one that a user installed.
# The function therefore loads that completion itself and adds a condition to its rules, so that
# they stay silent after `<command> nx`, where only the Nx candidates are wanted.
#
#   __nx_complete_wrap <command> <directory of the calling completion file>
function __nx_complete_wrap --argument-names command own_dir
    set own_dir (path resolve -- $own_dir)
    set -l loaded 0
    set -l after_own 0
    for dir in $fish_complete_path
        if test $after_own -eq 0
            test (path resolve -- $dir) = $own_dir; and set after_own 1
            continue
        end
        # fish ranks its own completions above those that fish_update_completions generates from
        # man pages, which are the last directory.
        if test (path basename -- $dir) = generated_completions; and __nx_complete_source_builtin $command
            set loaded 1
            break
        end
        if test -f $dir/$command.fish
            source $dir/$command.fish
            set loaded 1
            break
        end
    end
    test $loaded -eq 1; or __nx_complete_source_builtin $command

    # `complete -c <command>` prints the rules as commands that can be run again.
    set -l rules (complete --command $command)
    complete --command $command --erase
    for rule in $rules
        eval $rule --condition "'not __nx_complete --wrapped'"
    end
    complete --command $command --no-files --condition '__nx_complete --wrapped' --arguments '(__nx_complete)'
end

# Sources the completion that is built into the fish binary (fish 4.1 and later); false without one.
function __nx_complete_source_builtin --argument-names command
    set -l script (status get-file completions/$command.fish 2>/dev/null); or return 1
    string join \n -- $script | source
end
