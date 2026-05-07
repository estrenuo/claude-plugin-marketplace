# False-positive exclusies voor wiki-lint

Toepassen bij elke algoritmische check (bare-alias links, broken links, orphans).
Strip of whitelist elk item hieronder vóór je een link als probleem rapporteert.

## FP-1: Wikilinks in code spans

Links binnen backticks (`` `[[slug|text]]` ``) zijn documentatie of voorbeelden,
geen navigeerbare links. Strip alle backtick-spans (`...`) volledig vóór je
wikilinks extraheert.

**Detectie-hint:** Verwijder alle `` `...` ``-segmenten uit de tekst vóór analyse.

## FP-2: Table-pipe escape in ingest-state.md

`[[slug\|Display]]` in Markdown-tabelcellen is correcte syntaxis — `\|` is de
display-separator die Obsidian in tabelcontext vereist. Behandel dit als een valide
piped link. De slug is alles vóór `\|`, de display-tekst is alles erna.

**Detectie-hint:** Bij het parsen van links in tabellen: behandel `\|` als `|`.
Rapporteer deze links niet als broken op basis van de backslash.

## FP-3: [[index]] links

`[[index]]` verwijst naar `index.md` in de vault-root (niet in `wiki/`). Obsidian
lost dit vault-breed op. Dit is geen broken link.

**Detectie-hint:** Whitelist `index` expliciet als geldig link-target, ongeacht of
`wiki/index.md` bestaat.

## FP-4: Vault-global links vanuit wiki/

Links vanuit `wiki/` naar pagina's buiten `wiki/` (bijv. `[[index]]`,
`[[CLAUDE]]`) zijn valide in Obsidian's vault-brede resolutie. Een checker die
alleen `wiki/` scant, produceert vals-positieven voor deze links.

**Detectie-hint:** Rapporteer een link alleen als broken als het target-bestand
nergens in de vault bestaat — niet alleen als het ontbreekt in `wiki/`.
