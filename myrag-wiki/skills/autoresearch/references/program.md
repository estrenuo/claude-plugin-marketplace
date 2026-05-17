# Research Program — myrag-wiki edition

Dit bestand configureert de autoresearch-loop. De `autoresearch` skill leest
het vóór elke run. Pas het aan om je domein en research-stijl te matchen.

Domein-specifieke afspraken (taal, tags, clusters, custom subdirs) horen in
`CLAUDE.md` van je vault — niet hier. Dit bestand gaat over *hoe* de loop
zoekt en filtert, niet *wat* je vault inhoudelijk doet.

---

## Onderzoeksdoelen

Standaard per sessie:

- Vind autoritatieve bronnen — prefereer in deze volgorde:
  1. Peer-reviewed papers (arXiv, journals)
  2. Officiële documentatie en primaire bronnen
  3. .edu / .gov / gevestigde uitgevers
  4. Erkende industry-publicaties
- Extract entiteiten (mensen, organisaties, producten, tools)
- Extract concepten en frameworks
- Markeer tegenstellingen tussen bronnen expliciet
- Identificeer open vragen en research-gaps
- Prefereer bronnen uit de laatste 2 jaar — tenzij het topic foundational is

---

## Confidence-scoring

Label elke niet-triviale claim met confidence:

- **high**: meerdere onafhankelijke autoritatieve bronnen zijn het eens
- **medium**: één goede bron, of bronnen zijn deels eens
- **low**: speculatie, opinie, single informele bron, of onverifiëerd

**Hoe schrijven:**
- High-claims → direct in de prose met `(zie [[<source-slug>|<Title>]])`
- Medium-claims → idem, met optionele kanttekening
- Low-claims → altijd in een callout:
  ```
  > [!gap] <claim>. Bron: [[<source-slug>|<Title>]]. Verifieer voor gebruik.
  ```

Markeer claims uit bronnen ouder dan 3 jaar als potentieel verouderd —
óók als de bron autoritatief is.

Geen hedging in de prose ("wellicht", "het lijkt", "misschien"). Onzekerheid
hoort in een `> [!gap]` callout zodat lint en wiki-query het kunnen zien.

---

## Loop-constraints

- Max research-rondes per topic: **3**
- Max nieuwe wiki-pagina's per sessie: **15**
- Max sources gefetched per ronde: **5**
- Bij overschrijden max-pagina's vóór loop klaar is: file wat je hebt, en
  noteer wat overgeslagen is in `## Open questions` van de synthesis.

---

## Output-stijl (myrag-conventies)

- Nederlands voor synthesis, callouts en log-entries — tenzij `CLAUDE.md`
  van de vault expliciet een andere taalregel zet.
- Declaratief, present tense.
- Cite elke niet-triviale claim met **piped wikilink**:
  `(zie [[<source-slug>|<Title>]])`. Nooit bare `[[Title]]`.
- Pagina's onder 200 lines — split anders.
- Geen hedging-taal in prose; gebruik `> [!gap]` callouts.
- `## Summary` altijd aanwezig (verplicht voor `regen-quick-indexes.py`),
  eerste zin is wat in `wiki/sources-index.md` of
  `wiki/concepts-index.md` belandt. Houd die eerste zin <160 chars en
  scherp.

---

## Domein-notes

De vault-specifieke domein-, taal- en tagafspraken staan in de
`Customization notes`-sectie van `CLAUDE.md` van de vault. Lees die vóór de
loop start (de `wiki-start` skill heeft dit normaliter al gedaan in de
sessie).

Voorbeelden hieronder zijn richtlijnen — pas aan in `CLAUDE.md`, niet hier.

**Voor AI / tech-research:**
- Prefereer: arXiv, officiële GitHub-repo's, officiële product-docs,
  Hacker News-discussies met hoge karma als pointers
- Let op: LLM-benchmarks zijn vaak gegamed — leaderboard-claims als low
  confidence behandelen tenzij onafhankelijk geverifieerd

**Voor business / market-research:**
- Prefereer: company filings, Crunchbase, Bloomberg, geverifieerde
  industry-rapporten
- Flag persberichten als low confidence zonder onafhankelijke verificatie

**Voor medisch / health-research:**
- Prefereer: PubMed, Cochrane reviews, peer-reviewed clinical trials
- Noteer altijd: sample-size, studie-type (RCT vs observationeel) en
  recency

**Voor data engineering / DDD (waarschijnlijk relevant voor deze vault):**
- Prefereer: originele papers (Inmon, Linstedt, Kimball), officiële vendor-
  docs, conference talks van bekende practitioners
- Flag blog posts als pointers naar primaire bronnen

---

## Exclusies — geen high-confidence cite

Nooit als high-confidence bron gebruiken:
- Reddit-posts of forums (alleen als pointer naar primaire bron)
- Social media posts
- Pagina's zonder datum
- Bronnen die hun eigen claims niet citeren
- AI-gegenereerde content zonder menselijke editorial review

---

## Integratie met myrag-skills

- **`wiki-query`**: na autoresearch zijn de pagina's via qmd vindbaar (mits
  `qmd update` is gedraaid in Stap 5.4 van de skill).
- **`wiki-lint`**: nieuwe pagina's worden meegenomen in de volgende lint-
  pass. Verwacht meldingen als je stubs hebt aangemaakt zonder ze te
  vullen — dat is expected.
- **`wiki-ingest`**: autoresearch raakt `raw/` nooit aan. Het schrijft
  alleen in `wiki/`. Wil je een research-bron ook in `raw/` opslaan,
  doe dat handmatig en draai daarna `wiki-ingest`.
- **`gap-detector` agent**: gebruikt in Stap 0B van de skill voor topic-
  suggestie zonder expliciet topic.
