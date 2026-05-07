# Graph-logica voor wiki-explore

Bash-commando's voor de graph-modus van wiki-explore.
Voer deze uit vanuit de vault root. Pas het WIKI_DIR-pad aan als de vault
op een andere locatie staat.

```bash
WIKI_DIR="/Users/sanderrobijns/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyRAG/wiki"
```

---

## Inbound-link-teller

Telt voor elke wiki-pagina hoeveel andere pagina's ernaar linken.
Geeft de top-20 meest gelinkte pagina's (hubs).

```bash
grep -rh '\[\[' "$WIKI_DIR" --include="*.md" \
  | grep -oP '(?<=\[\[)[^\]|]+' \
  | sort | uniq -c | sort -rn \
  | head -20
```

Uitleg:
- `grep -rh` — recursief zoeken, bestandsnamen niet in de uitvoer
- `grep -oP '(?<=\[\[)[^\]|]+'` — extraheer de slug (deel vóór `|` of `]]`)
- `sort | uniq -c` — tel voorkomens (= inbound links)
- `sort -rn` — sorteer aflopend op telling
- `head -20` — beperk tot top-20

**Beperking:** escaped pipes in tabel-cellen (`\|`) worden niet perfect afgehandeld.
Dit is acceptabel voor een structuuroverzicht — de topranking is betrouwbaar.

---

## Orphan-detector

Vindt wiki-pagina's die door geen enkele andere wiki-pagina gelinkt worden.

```bash
WIKI_DIR="/Users/sanderrobijns/Library/Mobile Documents/iCloud~md~obsidian/Documents/MyRAG/wiki"

# Verzamel alle slugs die ergens gelinkt worden
LINKED=$(grep -rh '\[\[' "$WIKI_DIR" --include="*.md" \
  | grep -oP '(?<=\[\[)[^\]|]+' | sort -u)

# Vergelijk met alle bestaande pagina's
find "$WIKI_DIR" -name "*.md" | while read -r f; do
  slug=$(basename "$f" .md)
  if ! echo "$LINKED" | grep -qx "$slug"; then
    echo "ORPHAN: $slug  ($f)"
  fi
done
```

Uitleg:
- `LINKED` bevat alle slugs die minstens één keer gelinkt worden
- `grep -qx` — exacte string match (geen gedeeltelijke matches)
- Uitvoer: bestandsnaam + volledig pad voor elke orphan

**Noot:** index.md (vault root) en ingest-state.md worden als orphan gerapporteerd
als ze niet gelinkt zijn vanuit wiki/. Dit is een bekend false positive — deze
bestanden leven buiten de wiki/-directory maar zijn valide wiki-artefacten.
