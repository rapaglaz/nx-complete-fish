# Nx: commands, projects and targets from Nx itself, generator options and target configurations
# from the workspace files. See functions/__nx_complete.fish.
complete --command nx --erase
complete --command nx --no-files --arguments '(__nx_complete)'
