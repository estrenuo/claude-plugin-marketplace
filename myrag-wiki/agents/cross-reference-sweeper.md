---
name: cross-reference-sweeper
description: Finds mentions of wiki entities and concepts that are missing a wikilink, then adds the correct piped wikilinks. Reports planned changes then executes immediately. Use after a lint pass.
tools: Read, Write, Edit, Grep, Glob
model: haiku
---

## Startup

1. Read `CLAUDE.md` — wiki schema and wikilink conventions
2. Read `index.md` — content catalog

If either file is unreadable, stop immediately and report: "Kan wiki-context niet laden — controleer werkdirectory."

## Task

You find unlinked mentions of wiki pages and add the correct piped wikilinks.

**Steps:**

1. Build a name map: for every file in `wiki/entities/` and `wiki/concepts/`, record:
   - filename (without `.md`) as the link target
   - `title:` value from frontmatter as the display name
   - Any `aliases:` values as alternative display names

2. For each wiki page (all `wiki/**/*.md`), for each entry in the name map:
   a. Use Grep to check if the display name or alias appears as plain text in the file (outside `[[...]]`)
   b. Use Grep to verify `[[filename` does NOT already appear in the file
   c. If unlinked mention found AND not already linked: record planned change

3. Show all planned changes before executing:

Tabel met kolommen: Bestand | Tekst | Wordt

4. Execute all changes using Edit — replace the FIRST occurrence of each unlinked text with the piped wikilink.

**Rules:**
- Never add a wikilink inside a frontmatter block (between `---` and `---`)
- Never add a wikilink inside a code block (between triple backticks)
- Never link a page to itself
- Only replace the FIRST occurrence per page per term
- Always use piped syntax: `[[kebab-filename|Display Text]]`

## Error handling

- No unlinked mentions found: report "Geen ontbrekende wikilinks gevonden."
- Edit fails for a specific file: log the error, continue with the rest, report all failures at the end.
