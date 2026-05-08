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

# Check 3: plugin.json bestaat
PLUGIN_JSON="${PLUGIN}/.claude-plugin/plugin.json"
[[ -f "$PLUGIN_JSON" ]] || error_exit "plugin not found: ${PLUGIN_JSON}"

# Check 4: plugin staat in marketplace.json
MARKETPLACE_JSON=".claude-plugin/marketplace.json"
[[ -f "$MARKETPLACE_JSON" ]] || error_exit "marketplace manifest not found: ${MARKETPLACE_JSON}"

if ! python3 - "$MARKETPLACE_JSON" "$PLUGIN" <<'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
names = [p.get("name") for p in data.get("plugins", [])]
sys.exit(0 if name in names else 1)
PY
then
  error_exit "plugin ${PLUGIN} not registered in ${MARKETPLACE_JSON}"
fi

# Read current version (uit plugin.json)
CURRENT=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f: print(json.load(f).get('version', ''))
" "$PLUGIN_JSON")

# Check 5: geldig semver X.Y.Z
if ! [[ "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  error_exit "current version is not valid semver: ${CURRENT}"
fi

# Compute nieuwe versie
IFS=. read -r MAJ MIN PAT <<< "$CURRENT"
case "$BUMP_TYPE" in
  patch) NEW="$MAJ.$MIN.$((PAT + 1))" ;;
  minor) NEW="$MAJ.$((MIN + 1)).0" ;;
  major) NEW="$((MAJ + 1)).0.0" ;;
esac

# (volgende tasks vullen rest in)
echo "would bump ${PLUGIN}: ${CURRENT} → ${NEW}"
