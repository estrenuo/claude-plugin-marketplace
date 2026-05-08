#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: bump-plugin.sh <plugin> <patch|minor|major> [--allow-dirty]
EOF
  exit 2
}

error_exit() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

# Parse args: 2 positionals + optional --allow-dirty (mag ook tussen positionals)
ALLOW_DIRTY=0
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --allow-dirty) ALLOW_DIRTY=1 ;;
    -*) usage ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

if [[ ${#POSITIONAL[@]} -ne 2 ]]; then
  usage
fi

PLUGIN="${POSITIONAL[0]}"
BUMP_TYPE="${POSITIONAL[1]}"

case "$BUMP_TYPE" in
  patch|minor|major) ;;
  *) error_exit "bump type must be patch, minor, or major (got: ${BUMP_TYPE})" ;;
esac

# (volgende tasks vullen rest in)
echo "skeleton OK: plugin=$PLUGIN bump=$BUMP_TYPE allow_dirty=$ALLOW_DIRTY"
