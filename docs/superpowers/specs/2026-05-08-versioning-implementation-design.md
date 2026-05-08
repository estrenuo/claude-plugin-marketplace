# Versioning-implementatie: bump-plugin.sh

**Datum:** 2026-05-08
**Status:** Goedgekeurd door user, klaar voor planning

## Context

`CONTRIBUTING.md` (root) beschrijft de versioning-conventie voor deze
marketplace: per-plugin semver, tag-formaat `<plugin>/v<x.y.z>`, en een
release-workflow van vijf handmatige stappen. Deze spec implementeert de
release-workflow als shell-script zodat bumps reproduceerbaar zijn en
foutgevoelige stappen (verkeerd tag-formaat, mismatch tussen `plugin.json`
en tag) door de tool worden afgevangen.

## Doel

Een shell-script `scripts/bump-plugin.sh` dat:

- de `version` in `<plugin>/.claude-plugin/plugin.json` bumpt volgens
  semver MAJOR/MINOR/PATCH;
- een commit maakt met die wijziging;
- een lokale git-tag `<plugin>/v<new-version>` plaatst;
- de push aan de gebruiker overlaat (jij voert zelf
  `git push origin main --follow-tags` uit).

Buiten scope in v1: GitHub release-aanmaak, changelog-generatie, push,
pre-release versies (`-rc.1`, `-beta.1`).

## Interface

```text
scripts/bump-plugin.sh <plugin-name> <patch|minor|major> [--allow-dirty]
```

Voorbeelden:

```text
scripts/bump-plugin.sh myrag-wiki patch
scripts/bump-plugin.sh myrag-wiki minor
scripts/bump-plugin.sh myrag-wiki major --allow-dirty
```

Output bij succes (en alleen dan):

```text
✓ Bumped myrag-wiki: 0.1.0 → 0.2.0
✓ Committed: <sha7>
✓ Tagged: myrag-wiki/v0.2.0

Push: git push origin main --follow-tags
```

Stilte bij `set -e`-fails moet vermeden worden — alle exits gaan via
expliciete `error_exit` met stderr-melding.

## Validatie & safety checks

Volgorde matters: cheap checks eerst, mutatie pas na alle checks.

| # | Check | Foutmelding bij faal |
|---|-------|----------------------|
| 1 | Args: 2 positionals + optionele `--allow-dirty` | `usage: bump-plugin.sh <plugin> <patch\|minor\|major> [--allow-dirty]` |
| 2 | Bump-type ∈ `{patch, minor, major}` | `bump type must be patch, minor, or major (got: <value>)` |
| 3 | `<plugin>/.claude-plugin/plugin.json` bestaat | `plugin not found: <plugin>/.claude-plugin/plugin.json` |
| 4 | Plugin staat in `.claude-plugin/marketplace.json` (`plugins[].name`) | `plugin <plugin> not registered in .claude-plugin/marketplace.json` |
| 5 | `version` veld matcht `^[0-9]+\.[0-9]+\.[0-9]+$` | `current version is not valid semver: <value>` |
| 6 | `git status --porcelain` is leeg, tenzij `--allow-dirty` | `working tree not clean — commit/stash or pass --allow-dirty` |
| 7 | `git branch --show-current` == `main` | `not on main branch (on: <name>) — switch to main first` |
| 8 | Tag `<plugin>/v<new-version>` bestaat lokaal nog niet | `tag <plugin>/v<new-version> already exists` |
| 9 | `python3` beschikbaar op PATH | `python3 is required for JSON edit but not found on PATH` |

Notes:

- Check 4 voorkomt typos in plugin-naam.
- Check 6's `--allow-dirty` escape is voor PR-flows waarin de bump samen
  met andere wijzigingen gaat. Default streng.
- Check 7 niet-escapeable in v1. Releases vanaf andere branches kan later
  via `--branch`, niet nu.
- Check 8 controleert lokaal via `git rev-parse --verify`. Remote-only
  tags zien we pas bij `git push`. Geen netwerkcall in dit script.

Exit codes:

| Code | Betekenis |
|------|-----------|
| 0 | Succes |
| 1 | Validatie- of operatiefout (alle checks + git-failures) |
| 2 | Usage error (verkeerde args, hoort bij check 1) |

## Bump-logica

Pure shell, geen externe dep:

```bash
IFS=. read -r MAJ MIN PAT <<< "$CURRENT"
case "$BUMP_TYPE" in
  patch) NEW="$MAJ.$MIN.$((PAT + 1))" ;;
  minor) NEW="$MAJ.$((MIN + 1)).0" ;;
  major) NEW="$((MAJ + 1)).0.0" ;;
esac
```

Geen pre-release / build-metadata support in v1 — `CONTRIBUTING.md`
schrijft alleen `X.Y.Z` voor.

## JSON-edit

Bash voor orkestratie, `python3 -c` voor de JSON-mutatie. Python is op
macOS en Linux altijd aanwezig; geen `jq`-install vereist.

Skelet:

```bash
python3 - "$PLUGIN_JSON" "$CURRENT" "$NEW" <<'PY'
import json, sys
path, expected, new_version = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
if data.get("version") != expected:
    raise SystemExit(f"version mismatch: expected {expected}, got {data.get('version')}")
data["version"] = new_version
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY
```

Drie keuzes, expliciet:

1. **`indent=2`** — herschrijft `plugin.json` met canonical formatting.
   Eenmalige normalisatie bij eerste run; daarna stabiel.
2. **`ensure_ascii=False`** — behoudt accenten (`é`, `ë`) in `description`
   en `author`-velden in plaats van ze te escapen naar `é`.
3. **Trailing newline** — POSIX-conform, voorkomt onnodige diff-noise.

De Python-stap doet zelf nog een `version mismatch`-check als extra
paranoia tegen race conditions tussen shell-read en Python-write.

## Git operations

Sequentieel, faal-vroeg, geen `--no-verify`:

```bash
git add "$PLUGIN_JSON"
git commit -m "$PLUGIN: bump to $NEW"
git tag -a "$PLUGIN/v$NEW" -m "$PLUGIN v$NEW"
```

**Annotated tag** (`-a`) is bewust gekozen, niet lightweight: dit zet
auteur, datum en message op de tag, werkt met `git describe`, en is een
voorwaarde voor de gebruikers-push-instructie `git push origin main
--follow-tags` (dat alleen annotated, reachable tags meestuurt — veiliger
dan `--tags`).

Pre-commit hooks moeten slagen. Als die falen is de bump-poging zelf
ongeldig; de gebruiker fixt en herstart.

## Error handling & rollback

**Filosofie:** fail-loud-no-rollback. Cleanup-traps in bash zijn berucht
voor data-loss bugs. Liever een halve staat die zichtbaar is dan een
te-slim revert die fout gaat.

| Faalpunt | Staat na faal | Boodschap |
|----------|---------------|-----------|
| `git commit` faalt (hook) | `plugin.json` is gemuteerd en staged, geen commit | `commit failed — plugin.json edit is staged but not committed; fix and re-run` |
| `git tag` faalt | Commit staat, geen tag | `tag failed; commit <sha> exists, run 'git tag <plugin>/v<new>' manually` |

Beide cases: exit 1, gebruiker beslist hoe verder.

## File layout

Nieuw:

```text
scripts/
  bump-plugin.sh       # ~80-100 regels, executable (chmod +x)
```

`CONTRIBUTING.md` wordt aangepast op twee plekken:

1. De "Release-workflow"-sectie verwijst naar `scripts/bump-plugin.sh`
   als manier om de version-bump, de commit en de tag in één run te
   doen. Het bepalen van het bump-type (MAJOR/MINOR/PATCH) blijft een
   menselijke beslissing vooraf, en de push (`git push origin main
   --follow-tags`) blijft een expliciete handmatige stap erna.
2. Het push-commando in CONTRIBUTING wordt `--follow-tags` in plaats van
   `--tags`, omdat het script annotated tags maakt en dit veiliger pusht
   (alleen tags die bij gepushte commits horen).

## Testen

Geen formele testsuite. Acceptatietests via een wegwerp-worktree:

| # | Scenario | Verwacht |
|---|----------|----------|
| 1 | `bump-plugin.sh myrag-wiki patch` op schone main | `0.1.0 → 0.1.1`, commit + tag aanwezig |
| 2 | `bump-plugin.sh myrag-wiki minor` | `0.1.1 → 0.2.0` |
| 3 | `bump-plugin.sh myrag-wiki major` | `0.2.0 → 1.0.0` |
| 4 | `bump-plugin.sh nonexistent patch` | check 3 faalt, exit 1 |
| 5 | `bump-plugin.sh myrag-wiki bogus` | check 2 faalt, exit 1 |
| 6a | Dirty tree | check 6 faalt, exit 1 |
| 6b | Dirty tree + `--allow-dirty` | slaagt |
| 7 | Op feature-branch | check 7 faalt, exit 1 |
| 8 | Tag bestaat al | check 8 faalt, exit 1 |
| 9 | Mismatch in `plugin.json` na shell-read | Python-check faalt, exit 1 |

Geen committed `tests/` directory in v1. Latere uitbreiding kan via
`bats` of een eenvoudige `tests/bump-plugin.test.sh`.

## Buiten scope (v1)

- Push of remote-tag-check (`git ls-remote`).
- Auto-aanmaken van GitHub release of changelog.
- Pre-release-versies (`0.2.0-rc.1`).
- Multi-plugin bump in één run.
- Bump vanaf andere branch dan `main`.
- Een `tests/` directory met geautomatiseerde acceptatietests.

Elk van deze kan in v2+ als losse spec.

## Acceptance criteria

1. Script bestaat op `scripts/bump-plugin.sh`, executable.
2. Alle 9 checks zijn geïmplementeerd en getest met scenario's 4-9 hierboven.
3. Scenario's 1-3 tonen correcte semver-bumps en juiste tag-namen.
4. `CONTRIBUTING.md` verwijst naar het script in de release-workflow.
5. Geen externe deps anders dan `bash`, `git`, `python3`.
