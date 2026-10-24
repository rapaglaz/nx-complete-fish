#!/usr/bin/env bash
#
# Prepares a release on main: writes CHANGELOG.md with git-cliff, commits it and creates a signed
# tag vX.Y.Z. Without an argument, git-cliff computes the version from the commits since the last
# tag (cliff.toml, [bump]). Nothing is pushed; the script prints the push command.
#
# Usage: bash scripts/release.sh [vX.Y.Z] (or `mise run release`)

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ "$(git branch --show-current)" != main ]]; then
    echo "Releases are made on main." >&2
    exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
    echo "The working tree has changes; commit or stash them first." >&2
    exit 1
fi

version="${1:-$(git cliff --bumped-version)}"
if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Expected a version like v0.1.0, got: $version" >&2
    exit 1
fi
if git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
    echo "The tag $version exists already." >&2
    exit 1
fi

git cliff --tag "$version" --output CHANGELOG.md
git add CHANGELOG.md
git commit -S -m "chore(release): $version"
git tag -s "$version" -m "$version"

echo "Created the commit and the signed tag $version. Publish them with:"
echo "  git push origin main $version"
