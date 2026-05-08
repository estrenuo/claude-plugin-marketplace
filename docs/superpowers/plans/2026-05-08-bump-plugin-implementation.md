# bump-plugin.sh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementeer `scripts/bump-plugin.sh` dat de versioning-conventie uit `CONTRIBUTING.md` (per-plugin semver, tag-formaat `<plugin>/v<x.y.z>`) automatiseert: bump version in `plugin.json`, commit, annotated tag. Lokale operaties; push blijft handmatig.

**Architecture:** Pure bash voor flow en validatie, `python3 -c` inline voor JSON-mutatie en marketplace-lookup. Faal-vroeg met expliciete `error_exit`-helper en `set -euo pipefail`. Geen externe deps anders dan `bash`, `git`, `python3`.

**Tech Stack:** bash 3.2+ (macOS default), git, python3 (macOS/Linux default).

**Spec:** `docs/superpowers/specs/2026-05-08-versioning-implementation-design.md`

---

## File Structure

| File | Status | Verantwoordelijkheid |
|------|--------|----------------------|
| `scripts/bump-plugin.sh` | Create | Eindstuk script — alle logica leeft hier (~100 regels). Geen libraries, geen split. Eén verantwoordelijkheid: een plugin bumpen + committen + taggen. |
| `CONTRIBUTING.md` | Modify | Release-workflow-sectie verwijst naar het script; push-commando wordt `--follow-tags`. |

Geen `tests/` directory — spec zegt expliciet: acceptatietests via wegwerp-worktree per uitvoering, niets gecommit.

## TDD-aanpak voor shell-scripts

Klassieke "schrijf failing test → faal → implement → slaag" wordt hier vertaald naar:

1. Definieer scenario (commando + verwachte exit code + verwachte stderr-fragment).
2. Run het scenario tegen de huidige staat van het script — verifieer het faalt zoals verwacht (of niet bestaat).
3. Implementeer minimale code voor dit scenario.
4. Run scenario — moet slagen.
5. Commit.

Scenario's draaien in de **huidige werkdirectory** (de feature-worktree die je voor deze implementatie hebt aangemaakt, of `main` als je in-place werkt). Voor scenario's die fixtures buiten de echte plugins nodig hebben, maak en verwijder je een `tmp-plugin/`-directory binnen het scenario zelf.

---

## Task 1: Script-skelet + arg-parsing + bump-type validatie

Implementeert spec-checks 1 (usage) en 2 (bump-type).

**Files:**
- Create: `scripts/bump-plugin.sh`

- [ ] **Step 1: Failing scenario — geen args**

```bash
bash scripts/bump-plugin.sh
echo "exit=$?"
```

Expected: exit 2, stderr bevat `usage: bump-plugin.sh <plugin> <patch|minor|major>`.

Eerste keer: script bestaat nog niet → `bash: scripts/bump-plugin.sh: No such file or directory`, exit 127. Dat telt als "failing". Bevestig dat het scenario nog niet groen is.

- [ ] **Step 2: Failing scenario — bogus bump-type**

```bash
bash scripts/bump-plugin.sh myrag-wiki bogus
echo "exit=$?"
```

Expected (na implementatie): exit 1, stderr bevat `bump type must be patch, minor, or major (got: bogus)`.

Eerste keer: ook niet bestaand → exit 127. OK.

- [ ] **Step 3: Implementeer het skelet**

Maak `scripts/bump-plugin.sh` met deze inhoud:

```bash
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
```

Maak executable:

```bash
chmod +x scripts/bump-plugin.sh
```

- [ ] **Step 4: Verifieer beide scenario's**

```bash
bash scripts/bump-plugin.sh; echo "exit=$?"
bash scripts/bump-plugin.sh myrag-wiki bogus; echo "exit=$?"
bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
```

Expected:
- Eerste: exit 2, usage-regel op stderr.
- Tweede: exit 1, "bump type must be..." op stderr.
- Derde: exit 0, regel `skeleton OK: plugin=myrag-wiki bump=patch allow_dirty=0` op stdout.

- [ ] **Step 5: Commit**

```bash
git add scripts/bump-plugin.sh
git commit -m "scripts/bump-plugin.sh: skelet + arg-parsing + bump-type validatie"
```

---

## Task 2: Plugin discovery + marketplace-registratie

Implementeert spec-checks 3 (plugin.json bestaat) en 4 (plugin geregistreerd in `marketplace.json`).

**Files:**
- Modify: `scripts/bump-plugin.sh` (verwijder de `echo "skeleton OK"`-regel; voeg checks toe)

- [ ] **Step 1: Failing scenario — niet-bestaande plugin**

```bash
bash scripts/bump-plugin.sh nonexistent patch; echo "exit=$?"
```

Expected (na impl): exit 1, stderr bevat `plugin not found: nonexistent/.claude-plugin/plugin.json`.

Huidige staat: script print `skeleton OK: plugin=nonexistent ...` en exit 0. Dat is failing voor dit scenario.

- [ ] **Step 2: Failing scenario — plugin.json bestaat maar niet in marketplace.json**

```bash
mkdir -p tmp-plugin/.claude-plugin
cat > tmp-plugin/.claude-plugin/plugin.json <<'EOF'
{"name": "tmp-plugin", "version": "0.1.0"}
EOF

bash scripts/bump-plugin.sh tmp-plugin patch; echo "exit=$?"

rm -rf tmp-plugin
```

Expected (na impl): exit 1, stderr bevat `plugin tmp-plugin not registered in .claude-plugin/marketplace.json`.

Huidige staat: script print `skeleton OK` en exit 0. Failing.

- [ ] **Step 3: Implementeer checks 3 en 4**

Vervang de `echo "skeleton OK"`-regel onderaan het script met:

```bash
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

# (volgende tasks vullen rest in)
echo "discovery OK: ${PLUGIN_JSON} registered"
```

- [ ] **Step 4: Verifieer beide scenario's**

```bash
# Scenario 1
bash scripts/bump-plugin.sh nonexistent patch; echo "exit=$?"

# Scenario 2 (recreate fixture)
mkdir -p tmp-plugin/.claude-plugin
echo '{"name":"tmp-plugin","version":"0.1.0"}' > tmp-plugin/.claude-plugin/plugin.json
bash scripts/bump-plugin.sh tmp-plugin patch; echo "exit=$?"
rm -rf tmp-plugin

# Happy path: bestaande, geregistreerde plugin
bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
```

Expected:
- Scenario 1: exit 1, "plugin not found: nonexistent/...".
- Scenario 2: exit 1, "plugin tmp-plugin not registered...".
- Happy: exit 0, regel `discovery OK: myrag-wiki/.claude-plugin/plugin.json registered`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bump-plugin.sh
git commit -m "scripts/bump-plugin.sh: checks voor plugin.json en marketplace registratie"
```

---

## Task 3: Versie-lezen + semver bump-logica

Implementeert spec-check 5 (version is geldig semver) en de bump-math.

**Files:**
- Modify: `scripts/bump-plugin.sh` (verwijder `echo "discovery OK"`; voeg version-read + bump-math toe; eindig met print + exit zodat we kunnen verifiëren zonder mutaties)

- [ ] **Step 1: Failing scenario — ongeldige versie**

```bash
mkdir -p tmp-plugin/.claude-plugin
cat > tmp-plugin/.claude-plugin/plugin.json <<'EOF'
{"name": "tmp-plugin", "version": "abc"}
EOF
# Voeg tijdelijk toe aan marketplace.json
python3 - <<'PY'
import json
with open(".claude-plugin/marketplace.json") as f: data = json.load(f)
data["plugins"].append({"name": "tmp-plugin", "source": "./tmp-plugin", "description": "test"})
with open(".claude-plugin/marketplace.json", "w") as f: json.dump(data, f, indent=2); f.write("\n")
PY

bash scripts/bump-plugin.sh tmp-plugin patch; echo "exit=$?"

# Cleanup
git checkout .claude-plugin/marketplace.json
rm -rf tmp-plugin
```

Expected (na impl): exit 1, stderr bevat `current version is not valid semver: abc`.

Huidige staat: script print `discovery OK: ...` voor tmp-plugin en exit 0 (na fixture-toevoeging). Failing.

- [ ] **Step 2: Failing scenario — bump-math zichtbaar**

```bash
bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
bash scripts/bump-plugin.sh myrag-wiki minor; echo "exit=$?"
bash scripts/bump-plugin.sh myrag-wiki major; echo "exit=$?"
```

Expected (na impl, op `myrag-wiki` v0.1.0):
- patch: exit 0, regel `would bump myrag-wiki: 0.1.0 → 0.1.1`.
- minor: exit 0, regel `would bump myrag-wiki: 0.1.0 → 0.2.0`.
- major: exit 0, regel `would bump myrag-wiki: 0.1.0 → 1.0.0`.

Huidige staat: alle drie tonen `discovery OK: ...`. Failing.

- [ ] **Step 3: Implementeer version-read + bump-math**

Vervang `echo "discovery OK..."` met:

```bash
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
```

- [ ] **Step 4: Verifieer scenario's**

Voer beide scenario's uit Step 1 en Step 2 opnieuw uit. Verifieer:
- Step 1: exit 1, "current version is not valid semver: abc".
- Step 2: drie correcte `would bump`-regels.

- [ ] **Step 5: Commit**

```bash
git add scripts/bump-plugin.sh
git commit -m "scripts/bump-plugin.sh: version-read en semver bump-math"
```

---

## Task 4: Repo-state checks (working tree, branch, tag, python3)

Implementeert spec-checks 6, 7, 8 en 9.

**Files:**
- Modify: `scripts/bump-plugin.sh` (voeg checks toe vóór de `echo "would bump..."`-regel; check 9 staat bovenaan vóór alle Python-aanroepen)

- [ ] **Step 1: Failing scenario — dirty tree**

```bash
echo "scratch" > /tmp/scratch && cp /tmp/scratch ./scratch.txt

bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
bash scripts/bump-plugin.sh myrag-wiki patch --allow-dirty; echo "exit=$?"

rm scratch.txt
```

Expected (na impl):
- Eerste: exit 1, stderr bevat `working tree not clean — commit/stash or pass --allow-dirty`.
- Tweede: exit 0 (of een latere check faalt — niet check 6).

Huidige staat: beide tonen `would bump ...`. Failing voor scenario 1.

- [ ] **Step 2: Failing scenario — feature branch**

```bash
git checkout -b tmp-feature
bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
git checkout main
git branch -D tmp-feature
```

Expected (na impl): exit 1, stderr bevat `not on main branch (on: tmp-feature) — switch to main first`.

- [ ] **Step 3: Failing scenario — tag bestaat al**

```bash
git tag myrag-wiki/v0.1.1
bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
git tag -d myrag-wiki/v0.1.1
```

Expected (na impl, op myrag-wiki v0.1.0): exit 1, stderr bevat `tag myrag-wiki/v0.1.1 already exists`.

- [ ] **Step 4: Implementeer checks 6, 7, 8 en 9**

Voeg vóór de `# Read current version`-block (uit Task 3) deze blokken toe; en check 9 helemaal bovenaan vóór de eerste python3-aanroep:

Vervang het begin van de checks-sectie zodat deze structuur ontstaat:

```bash
# Check 9: python3 beschikbaar (vóór eerste python-aanroep!)
command -v python3 >/dev/null 2>&1 \
  || error_exit "python3 is required for JSON edit but not found on PATH"

# (Check 3 en 4 zoals in Task 2)
PLUGIN_JSON="${PLUGIN}/.claude-plugin/plugin.json"
[[ -f "$PLUGIN_JSON" ]] || error_exit "plugin not found: ${PLUGIN_JSON}"
# ... (rest van check 4 onveranderd) ...

# (Check 5 en bump-math zoals in Task 3, leveren $CURRENT en $NEW)
# ...

# Check 6: working tree clean
if [[ "$ALLOW_DIRTY" -eq 0 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    error_exit "working tree not clean — commit/stash or pass --allow-dirty"
  fi
fi

# Check 7: op main branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
  error_exit "not on main branch (on: ${CURRENT_BRANCH}) — switch to main first"
fi

# Check 8: tag bestaat nog niet (lokaal)
TAG="${PLUGIN}/v${NEW}"
if git rev-parse --verify --quiet "refs/tags/${TAG}" >/dev/null; then
  error_exit "tag ${TAG} already exists"
fi

# (volgende tasks vullen rest in)
echo "would bump ${PLUGIN}: ${CURRENT} → ${NEW}"
echo "would tag: ${TAG}"
```

**Volgorde-opmerking:** check 9 staat bovenaan; checks 6-7-8 staan na version-read omdat check 8 `$NEW` nodig heeft. Dit is correct; cheap arg-checks (1, 2) blijven vooraan, file-checks (3, 4, 9) volgen, dan version-read+math, dan repo-state (6, 7, 8).

- [ ] **Step 5: Verifieer alle vier scenario's**

```bash
# Scenario 1: dirty tree
echo s > scratch.txt
bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
bash scripts/bump-plugin.sh myrag-wiki patch --allow-dirty; echo "exit=$?"
rm scratch.txt

# Scenario 2: feature branch
git checkout -b tmp-feature
bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
git checkout main && git branch -D tmp-feature

# Scenario 3: bestaande tag
git tag myrag-wiki/v0.1.1
bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
git tag -d myrag-wiki/v0.1.1

# Scenario 4 (python3-check): mock door PATH te beperken
PATH="/usr/bin" bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"
```

Expected:
- Scenario 1 #1: exit 1, "working tree not clean…".
- Scenario 1 #2: exit 0, twee `would …`-regels (allow-dirty escaped).
- Scenario 2: exit 1, "not on main branch (on: tmp-feature)…".
- Scenario 3: exit 1, "tag myrag-wiki/v0.1.1 already exists".
- Scenario 4: exit 1, "python3 is required…" (op systemen waar `/usr/bin/python3` ontbreekt; op recent macOS staat python3 in `/usr/bin` dus deze test faalt soft — accepteer dit).

- [ ] **Step 6: Commit**

```bash
git add scripts/bump-plugin.sh
git commit -m "scripts/bump-plugin.sh: checks voor working tree, branch, tag en python3"
```

---

## Task 5: JSON-mutatie (canonical, ensure_ascii=False, trailing newline)

Implementeert de echte JSON-edit. Vóór deze task printte het script alleen `would bump …`; nu schrijft het.

**Files:**
- Modify: `scripts/bump-plugin.sh` (vervang `echo "would …"`-regels met daadwerkelijke mutatie)

- [ ] **Step 1: Failing scenario — accenten worden behouden**

Setup:

```bash
# Backup huidige plugin.json
cp myrag-wiki/.claude-plugin/plugin.json /tmp/plugin.json.bak

# Voeg een accent toe aan description om escapen te kunnen detecteren
python3 - <<'PY'
import json
p = "myrag-wiki/.claude-plugin/plugin.json"
with open(p) as f: data = json.load(f)
data["description"] = "Wiki maintainer skills — étoile."
with open(p, "w") as f: json.dump(data, f, indent=2); f.write("\n")
PY
```

Run script (let op: dirty tree dus `--allow-dirty`):

```bash
bash scripts/bump-plugin.sh myrag-wiki patch --allow-dirty; echo "exit=$?"
grep -F 'étoile' myrag-wiki/.claude-plugin/plugin.json && echo "ACCENT KEPT" || echo "ACCENT LOST"
grep -F '"version": "0.1.1"' myrag-wiki/.claude-plugin/plugin.json && echo "VERSION BUMPED" || echo "VERSION NOT BUMPED"
```

Expected (na impl): exit 0, regels `ACCENT KEPT` en `VERSION BUMPED`.

Cleanup:

```bash
mv /tmp/plugin.json.bak myrag-wiki/.claude-plugin/plugin.json
```

Huidige staat (vóór impl): script print `would …`-regels en wijzigt het bestand niet → `VERSION NOT BUMPED`. Failing.

- [ ] **Step 2: Failing scenario — mismatch detectie**

Geforceerde race condition simuleren:

```bash
cp myrag-wiki/.claude-plugin/plugin.json /tmp/plugin.json.bak
# Maak een handmatige mutatie die het script niet verwacht
python3 - <<'PY'
import json
p = "myrag-wiki/.claude-plugin/plugin.json"
with open(p) as f: data = json.load(f)
data["version"] = "9.9.9"
with open(p, "w") as f: json.dump(data, f, indent=2); f.write("\n")
PY
```

We willen check 5 (geldig semver) NIET triggeren — `9.9.9` is geldig. We hebben een ander mechanisme nodig om de mismatch-check binnen Python te triggeren. Dat lukt niet eenvoudig zonder het script te onderbreken.

**Praktische conclusie:** scenario 9 uit de spec ("mismatch") is een paranoid runtime-check binnen Python die niet eenvoudig artificieel reproduceerbaar is in een acceptatietest. We *implementeren* hem (zie Step 3), maar testen hem **alleen via code-inspectie**: bevestig dat de Python-block `expected != got`-check bevat.

Cleanup:

```bash
mv /tmp/plugin.json.bak myrag-wiki/.claude-plugin/plugin.json
```

- [ ] **Step 3: Implementeer JSON-edit**

Vervang in het script de twee `echo "would …"`-regels met:

```bash
# Mutate plugin.json (canonical re-format, behoudt accenten)
python3 - "$PLUGIN_JSON" "$CURRENT" "$NEW" <<'PY'
import json, sys
path, expected, new_version = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
got = data.get("version")
if got != expected:
    raise SystemExit(f"version mismatch: expected {expected}, got {got}")
data["version"] = new_version
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")
PY

# (volgende task voegt git ops toe)
echo "mutated ${PLUGIN_JSON}: ${CURRENT} → ${NEW}"
```

- [ ] **Step 4: Verifieer Step 1 scenario**

Run de Step 1 setup, het script-commando, en de greps. Verifieer:
- exit 0
- `ACCENT KEPT`
- `VERSION BUMPED`

Reset daarna `myrag-wiki/.claude-plugin/plugin.json` via `git checkout myrag-wiki/.claude-plugin/plugin.json` (dan ben je terug op v0.1.0 zonder de accent-fixture).

- [ ] **Step 5: Verifieer mismatch-check via code-inspectie**

```bash
grep -E 'version mismatch.*expected.*got' scripts/bump-plugin.sh
```

Expected: regel met de mismatch-error in de Python-block. Dat bewijst dat de runtime-check geïmplementeerd is.

- [ ] **Step 6: Commit**

```bash
git add scripts/bump-plugin.sh
git commit -m "scripts/bump-plugin.sh: JSON-mutatie van plugin.json"
```

---

## Task 6: Git operations + success output

Implementeert de commit, annotated tag, en de uiteindelijke success-print uit de spec.

**Files:**
- Modify: `scripts/bump-plugin.sh` (vervang `echo "mutated …"` met git-ops + success-blok)

- [ ] **Step 1: Failing scenario — end-to-end op myrag-wiki**

```bash
# Vooraf: zorg voor schone repo op main
git status

bash scripts/bump-plugin.sh myrag-wiki patch; echo "exit=$?"

# Verificaties
git log --oneline -1
git tag --list 'myrag-wiki/v*'
python3 -c "import json; print(json.load(open('myrag-wiki/.claude-plugin/plugin.json'))['version'])"

# Reset (we testen alleen, niet pushen)
git reset --hard HEAD~1
git tag -d myrag-wiki/v0.1.1
```

Expected (na impl):
- exit 0
- Output:
  ```
  ✓ Bumped myrag-wiki: 0.1.0 → 0.1.1
  ✓ Committed: <sha7>
  ✓ Tagged: myrag-wiki/v0.1.1
  
  Push: git push origin main --follow-tags
  ```
- `git log` toont commit "myrag-wiki: bump to 0.1.1".
- `git tag --list` toont `myrag-wiki/v0.1.1`.
- `plugin.json` toont version `0.1.1`.

Huidige staat (vóór impl): `mutated …` regel, geen commit, geen tag. Failing.

- [ ] **Step 2: Implementeer git ops + success output**

Vervang `echo "mutated …"` aan het einde van het script met:

```bash
# Git operations
git add "$PLUGIN_JSON"
if ! git commit -m "${PLUGIN}: bump to ${NEW}"; then
  error_exit "commit failed — plugin.json edit is staged but not committed; fix and re-run"
fi
COMMIT_SHA=$(git rev-parse --short HEAD)

if ! git tag -a "$TAG" -m "${PLUGIN} v${NEW}"; then
  error_exit "tag failed; commit ${COMMIT_SHA} exists, run 'git tag -a ${TAG} -m \"${PLUGIN} v${NEW}\"' manually"
fi

# Success output
cat <<EOF
✓ Bumped ${PLUGIN}: ${CURRENT} → ${NEW}
✓ Committed: ${COMMIT_SHA}
✓ Tagged: ${TAG}

Push: git push origin main --follow-tags
EOF
```

- [ ] **Step 3: Verifieer Step 1 scenario**

Run het Step 1 commando-blok. Bevestig alle verificaties slagen. Voer daarna de reset uit:

```bash
git reset --hard HEAD~1
git tag -d myrag-wiki/v0.1.1
```

- [ ] **Step 4: Edge-case — commit-failure pad zichtbaar**

Snelle inspectie: zorg dat de error-paden voor commit-failure en tag-failure er staan.

```bash
grep -E 'commit failed.*staged but not committed' scripts/bump-plugin.sh
grep -E 'tag failed.*commit.*exists' scripts/bump-plugin.sh
```

Expected: beide grep-regels matchen.

- [ ] **Step 5: Commit**

```bash
git add scripts/bump-plugin.sh
git commit -m "scripts/bump-plugin.sh: git ops, annotated tag, success output"
```

---

## Task 7: CONTRIBUTING.md update + final acceptance

Verwerkt de CONTRIBUTING-aanpassingen uit de spec en voert het volledige acceptatie-pad door.

**Files:**
- Modify: `CONTRIBUTING.md`

- [ ] **Step 1: Failing scenario — CONTRIBUTING noemt het script niet**

```bash
grep -F 'scripts/bump-plugin.sh' CONTRIBUTING.md && echo "REFERENCED" || echo "NOT REFERENCED"
grep -E 'git push origin main --tags($|\s)' CONTRIBUTING.md && echo "OLD PUSH STILL THERE" || echo "OLD PUSH GONE"
grep -F 'git push origin main --follow-tags' CONTRIBUTING.md && echo "FOLLOW-TAGS REFERENCED" || echo "FOLLOW-TAGS MISSING"
```

Expected (na impl): `REFERENCED`, `OLD PUSH GONE`, `FOLLOW-TAGS REFERENCED`.

Huidige staat: `NOT REFERENCED`, `OLD PUSH STILL THERE`, `FOLLOW-TAGS MISSING`. Failing.

- [ ] **Step 2: Pas CONTRIBUTING.md aan**

Open `CONTRIBUTING.md`. Vervang het hele blok onder `## Release-workflow` met:

```markdown
## Release-workflow

Voor een plugin-release:

1. Bepaal het type bump (MAJOR / MINOR / PATCH) op basis van
   bovenstaande regels.
2. Voer het bump-script uit op `main`, op een schone working tree:

   ```bash
   scripts/bump-plugin.sh <plugin-name> <patch|minor|major>
   ```

   Voorbeeld:

   ```bash
   scripts/bump-plugin.sh myrag-wiki minor
   ```

   Het script muteert `version` in `<plugin>/.claude-plugin/plugin.json`,
   maakt een commit en plaatst een annotated tag `<plugin>/v<x.y.z>`.

3. Push wijzigingen en tag:

   ```bash
   git push origin main --follow-tags
   ```

4. Optioneel: schrijf een release-note op de bijbehorende GitHub release.

Als je in dezelfde PR ook code-changes wilt bumpen (nog niet
gecommit), gebruik `--allow-dirty`:

```bash
scripts/bump-plugin.sh myrag-wiki minor --allow-dirty
```
```

- [ ] **Step 3: Verifieer Step 1 grep-checks**

Run de drie greps uit Step 1 opnieuw. Verifieer: `REFERENCED`, `OLD PUSH GONE`, `FOLLOW-TAGS REFERENCED`.

- [ ] **Step 4: End-to-end happy-path acceptatie**

```bash
# Schoon op main beginnen — geen pending changes anders dan deze task
git status

# Run bump
bash scripts/bump-plugin.sh myrag-wiki patch
```

Expected: success-blok met `0.1.0 → 0.1.1`, exit 0.

```bash
# Verifieer staat
git log --oneline -1
git tag --list 'myrag-wiki/v*'
git show myrag-wiki/v0.1.1 | head -5  # annotated tag toont author/datum
python3 -c "import json; print(json.load(open('myrag-wiki/.claude-plugin/plugin.json'))['version'])"

# Rollback (we hebben echte release nog niet geautoriseerd)
git reset --hard HEAD~1
git tag -d myrag-wiki/v0.1.1
```

Expected:
- Commit "myrag-wiki: bump to 0.1.1".
- Tag `myrag-wiki/v0.1.1` aanwezig en annotated (`git show` toont auteur).
- Version is `0.1.1`.

- [ ] **Step 5: End-to-end acceptatie van alle 9 spec-scenario's**

Loop deze rij door, elk scenario in een schone state. Zie de tabel in spec-sectie *Testen* voor verwachte uitkomsten:

| # | Commando | Verwacht |
|---|----------|----------|
| 1 | `bash scripts/bump-plugin.sh myrag-wiki patch` (op clean main) | exit 0, 0.1.0 → 0.1.1; **rollback erna** |
| 2 | (na #1 nogmaals) `… patch` | exit 0, 0.1.1 → 0.1.2; **rollback** |
| 3 | `… major` (op clean main) | exit 0, 0.1.0 → 1.0.0; **rollback** |
| 4 | `bash scripts/bump-plugin.sh nonexistent patch` | exit 1, "plugin not found" |
| 5 | `bash scripts/bump-plugin.sh myrag-wiki bogus` | exit 1, "bump type must be…" |
| 6a | dirty tree → `… patch` | exit 1, "working tree not clean…" |
| 6b | dirty tree → `… patch --allow-dirty` | exit 0 |
| 7 | feature branch → `… patch` | exit 1, "not on main branch…" |
| 8 | met bestaande tag `myrag-wiki/v0.1.1` → `… patch` | exit 1, "tag … already exists" |
| 9 | code-inspectie | `grep 'version mismatch' scripts/bump-plugin.sh` matcht |

Schrijf na elk scenario een `OK`/`FAIL` regel in stdout. Stop bij eerste FAIL en debug.

Rollback-recept tussen scenario's:

```bash
git reset --hard HEAD~1  # alleen als er een commit is gemaakt
git tag -l 'myrag-wiki/v*' | xargs -r git tag -d  # ruim test-tags op
git checkout main  # voor zeker
```

- [ ] **Step 6: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "CONTRIBUTING.md: verwijs naar scripts/bump-plugin.sh en --follow-tags"
```

---

## Acceptance criteria recap

Vink af na alle tasks:

- [ ] `scripts/bump-plugin.sh` bestaat, executable.
- [ ] Alle 9 checks zijn geïmplementeerd; scenario's 4-9 in Task 7 Step 5 falen netjes.
- [ ] Scenario's 1-3 in Task 7 Step 5 tonen correcte semver-bumps en juiste tag-namen.
- [ ] `CONTRIBUTING.md` verwijst naar het script en gebruikt `--follow-tags`.
- [ ] Geen externe deps anders dan `bash`, `git`, `python3` (geen `jq`, geen `bats`).
- [ ] Tags die door het script gemaakt worden zijn annotated (`git show` toont author + message).
