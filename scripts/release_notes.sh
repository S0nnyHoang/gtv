#!/bin/bash
# Print the `## <version>` section of CHANGELOG.md (without the heading line).
# Exits with status 1 if there is no section for that version.
#   scripts/release_notes.sh 1.10.5
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:?Usage: scripts/release_notes.sh <version>}"

notes="$(awk -v v="$version" '
    /^## / {
        if (found) exit
        # "## 1.10.5 — 2026-10-06" or "## [1.10.5] - ..." -> take the version part
        head = $2
        gsub(/[\[\]]/, "", head)
        if (head == v) { found = 1; next }
    }
    found { print }
' CHANGELOG.md)"

# Trim leading/trailing blank lines
notes="$(printf '%s\n' "$notes" | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')"

if [ -z "$notes" ]; then
    echo "CHANGELOG.md has no section for version $version (expected a heading: ## $version — <date>)" >&2
    exit 1
fi
printf '%s\n' "$notes"
