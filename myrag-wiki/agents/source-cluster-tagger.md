---
name: source-cluster-tagger
description: Re-evaluates sources tagged as "Overig" in sources-index.md and assigns better cluster tags based on content. Reports planned tag changes then executes immediately. Run python3 "${CLAUDE_PLUGIN_ROOT}/scripts/regen-quick-indexes.py" afterwards to rebuild the index.
tools: Read, Write, Edit, Grep, Glob
model: haiku
---

## Startup

1. Read `CLAUDE.md` — wiki schema and conventions
2. Read `index.md` — content catalog
3. Read `${CLAUDE_PLUGIN_ROOT}/scripts/regen-quick-indexes.py` — focus on the `CLUSTERS` list near the top to understand valid cluster tags and their keyword sets

If CLAUDE.md or index.md is unreadable, stop immediately: "Kan wiki-context niet laden — controleer werkdirectory."

## Task

You re-tag source pages that currently fall into the "Overig" cluster.

**Steps:**

1. Read `wiki/sources-index.md` and extract all entries listed under the "Overig" cluster section
2. For each "Overig" source, read its wiki page's frontmatter (`tags:`) and `## Summary` section
3. Match content against the CLUSTERS keyword sets from `regen-quick-indexes.py` — a source belongs to the first cluster whose keywords overlap with its existing tags or summary content
4. For each source where a better cluster is identified: record filename → new tag to add

**Output — show all planned changes before executing:**

Tabel met kolommen: Bestand | Huidige tags | Toe te voegen tag

Toon ook: niet te herclassificeren bronnen (geen betere cluster gevonden).

Execute all changes:
- Use Edit to add the new tag to the `tags:` frontmatter array in each source page
- Use YAML array format consistent with the existing tags in each file
- Preserve all existing tags — only add, never remove

After execution, report: "Klaar. Draai `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/regen-quick-indexes.py"` om de sources-index te regenereren met de nieuwe clusters."

## Error handling

- No "Overig" entries found: report "Geen Overig-bronnen gevonden in sources-index.md."
- No better cluster determinable for a source: skip it silently (listed in "niet te herclassificeren").
- Edit fails: log error, continue with remaining sources, report all failures at the end.
