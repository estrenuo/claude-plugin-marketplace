---
name: wiki-ingest
description: |
  Gebruik deze skill wanneer de gebruiker een ingest-opdracht geeft voor de wiki:
  bronnen toevoegen, bestanden verwerken, nieuwe documenten importeren.
  Typische triggers: "ingest", "verwerk bronnen", "nieuwe bestanden verwerken",
  "voeg dit toe aan de wiki", "ingest <bestandsnaam>", "verwerk nieuwe bronnen",
  "scan de raw-map", "verwerk dit artikel", of informele varianten daarvan.
  Niet voor: wiki-inhoud opvragen (→ wiki-query), lint-controles (→ wiki-lint),
  wiki-overzicht (→ wiki-explore).
allowed-tools: Read, Write, Edit, Bash, Task, mcp__qmd__update
---

# wiki-ingest

Je bent de wiki-onderhouder. Codificeer de 10-staps ingest-workflow als rigide checklist. Sla geen stap over, ook niet als de bron al bekend lijkt.

---

## Stap 1 — Detectie (auto-modus)

Detecteer welke bestanden verwerkt moeten worden voordat je begint.

**Scan raw/:**
```bash
find raw/ -maxdepth 1 -type f \( -name "*.md" -o -name "*.pdf" \) | sort
```
Sla `raw/assets/` altijd over — dit zijn afbeeldingen, geen bronnen (INGS-06).

**Vergelijk met wiki/ingest-state.md.** Lees het bestand en classificeer elk gevonden bestand.
Zie `references/detection-logic.md` voor de exacte regels:
- De Morgan-regel (mtime ÉN hash — niet alleen mtime)
- Alle 4 detectiemodi: New / Modified / Unchanged / Deleted
- Bash-commando's voor mtime en hash
- Multi-page check bij Modified

**Toon classificatie vóór je begint:**
```
New (N): [namen]
Modified (N): [namen]
Unchanged (N): [namen]
Deleted/orphan (N): [namen]
```

Verwerk alleen New en Modified. Vraag bij Deleted altijd bevestiging vóór actie.

**Bereken de batch-count (INGS-01):**

`count = aantal New + aantal Modified` — dit is het aantal bronnen dat in deze run verwerkt wordt. Multi-page raws (één raw die meerdere wiki-pagina's voedt) tellen als 1 bron, ongeacht hoeveel wiki-pagina's geüpdatet worden.

Force-ingest (`ingest <bestandsnaam>`) heeft altijd `count = 1`.

---

## Stap 2 — Bepaal index-modus (INGS-01)

Op basis van de batch-count (uit Stap 1) bepaal je vóór de batch-loop welke index-onderhoudsmodus geldt voor deze hele run:

- **`count == 0`** → geen verwerking, geen index-update, geen qmd update. Alleen rapport (zie Stap 5).
- **`count >= 3`** → **regenerate-modus**: sla Stap 7 (patch quick-indexes) per file over. Roep aan het einde van de batch eenmalig `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/regen-quick-indexes.py"` aan vóór `qmd update`.
- **`count >= 1 en count < 3`** (dus 1 of 2) → **patch-modus**: voer Stap 7 normaal uit per file. Geen scriptaanroep.

**Annonceer de modus expliciet aan de gebruiker vóór je verder gaat:**
```
Index-modus: regenerate (count=N ≥ 3) — script wordt na batch aangeroepen
```
of
```
Index-modus: patch (count=N < 3) — per-file patches in Stap 7
```

**Edge cases (expliciet documenteren in deze sectie als bullet-lijst):**
- Force-ingest: altijd count=1 → patch-modus
- Multi-page raw met "alleen analyse"-keuze: telt nog steeds als 1
- Threshold is exact ≥3, niet >3 (dus 3 = regenerate, 2 = patch)
- count == 0: eigen no-op conditie — geen index-update, geen qmd update, wel rapport

---

## Stap 3 — Force-ingest modus

`ingest <bestandsnaam>` slaat detectie over en verwerkt het opgegeven bestand direct. Gebruik dit voor geforceerde herverwerking ongeacht mtime/hash-status.

- Als het bestand niet bestaat in `raw/`: geef foutmelding, stop — geen verdere stappen.
- Als het bestand meerdere wikilinks heeft in ingest-state.md: voer de multi-page dialoog uit vóór Stap 4 (zie Multi-page geval in Stap 4).
- Genereer altijd een volledig rapport via Stap 5, ook bij force-ingest van één bestand.
- count = 1 altijd → patch-modus.

**PDF-bronnen — delegeer naar `pdf-ingest-agent`:** als het te verwerken bestand
een `.pdf` is (geldt voor zowel auto-modus als force-ingest), roep de Task tool
aan met `subagent_type: pdf-ingest-agent` en geef het PDF-pad als input. De
agent doet chunked reading (max 20 pagina's per call) en voert de volledige
ingest-workflow uit. Sla Stap 4 voor dit specifieke bestand over en neem het
resultaat van de agent op in het Stap 5-rapport.

---

## Stap 4 — Batch-loop ingest-uitvoering (INGS-03)

**Fout-afhandeling per bestand:**
Als een bestand niet verwerkt kan worden (onleesbaar bestand, write-fout, onverwachte conditie), vang de fout op en ga door met het volgende bestand in de batch. Breek de batch nooit af vanwege één bestand. Noteer per mislukt bestand: de bestandsnaam en een korte foutmelding. Deze notities verwerkt Stap 5 naar de per-bestand tabel in het rapport.

Waarom: fout-abort veroorzaakt onvolledige batches en vereist handmatig herstart. Per-file continuering is robuuster en minder belastend voor de gebruiker.

Itereer over de werkverzameling (alle New + Modified bestanden uit Stap 1) en voer voor **elk** bestand de **ingest-stappen 1-9** (uit `references/ingest-steps.md`) sequentieel uit. De gebruiker hoeft het commando niet per bestand te herhalen — de hele batch verwerkt in één run.

De stappen 1-9 worden per bestand uitgevoerd. Stap 9.5 (regenerate, alleen in regenerate-modus) en Stap 10 (qmd update) zijn post-batch stappen — ze draaien eenmalig na afronding van alle bestanden.

In **regenerate-modus** sla Stap 7 (patch quick-indexes in ingest-steps.md) per-file over. In **patch-modus** voer je Stap 7 normaal uit per file.

Na afloop van de batch (in regenerate-modus): roep `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/regen-quick-indexes.py"` aan vóór Stap 10 (qmd update in ingest-steps.md).

Volledige stappen met why-zinnen en format-specs in `references/ingest-steps.md`.

**Samenvatting:**
1. Lees het bronbestand volledig (skip raw/assets/)
2. Bespreek 2-5 kernpunten — **wacht op bevestiging gebruiker vóór schrijven**
3. Schrijf/update wiki/sources/YYYY-MM-DD-slug.md
4. Update wiki/entities/*.md (nieuwe info, tegenstrijdigheden → ## Open questions)
5. Update wiki/concepts/*.md (idem)
6. Update index.md (entry toevoegen of verversen)
7. Patch wiki/sources-index.md en wiki/concepts-index.md (alleen patch-modus)
8. Append aan log.md (type: ingest of update)
9. Update wiki/ingest-state.md (mtime, hash, wikilink met `\|`-escape, datum)
9.5. (Regenerate-modus, post-batch) Run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/regen-quick-indexes.py"`
10. Roep `qmd update` aan via MCP — altijd als laatste stap, post-batch

**Multi-page geval:** Als Modified bestand meerdere wikilinks heeft in de Source page cel, voer dan de multi-page dialoog uit vóór stap 2. Details in `references/ingest-steps.md`.

---

## Stap 5 — Afsluitend rapport

Na verwerking van alle bestanden: genereer het rapport met 7 verplichte elementen.
Zie `references/report-format.md` voor het volledige template.

Minimaal vereist (INGS-07):
- **Tellingen:** N nieuw | N bijgewerkt | N ongewijzigd | N verwijderd | N mislukt
- **Per-bestand uitkomsten:** één tabelrij per bestand (ook ongewijzigde) met uitkomst en eventuele foutmelding
- **Index-modus:** patch / regenerate / n.v.t. + count + korte rationale
- **Pages touched:** welke pagina's aangemaakt of bijgewerkt
- **Contradictions found:** tegenstrijdigheden (of: Geen)
- **Stubs created:** nieuwe stubs (of: Geen)
- **Meest interessante bevinding:** nooit weglaten
- **Suggesties voor vervolgvragen:** aanbevolen maar niet verplicht

---

## Stap 6 — Optioneel: cluster-tags opschonen (post-batch)

Na een grote batch (count ≥ 5) of wanneer het Stap 5-rapport meldt dat nieuwe
sources in cluster "Overig" zijn beland: stel de gebruiker voor om de
`source-cluster-tagger` agent te draaien.

- Roep de Task tool aan met `subagent_type: source-cluster-tagger`
- De agent her-evalueert "Overig"-sources en wijst betere clustertags toe,
  voert de wijzigingen direct uit, en draagt op om
  `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/regen-quick-indexes.py"` te draaien
- Doe dit vóór `qmd update` als de gebruiker akkoord gaat; anders sla over

---

## Kwaliteitsregels

- Maak geen tweede bronpagina voor een al-getrackte raw — edit de bestaande rij
- Stap 2 (bespreek met gebruiker) nooit overslaan
- `stat -f` is macOS BSD-syntax — deze skill werkt alleen op macOS
- ingest-state.md tabel: gebruik `\|` als pipe-escape in wikilinks binnen tabelcellen
