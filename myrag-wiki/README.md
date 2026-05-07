# myrag-wiki plugin

Skills + agents voor het onderhouden van een Obsidian-based LLM wiki (zie `CLAUDE.md` in de bovenliggende repo voor het volledige schema).

## Bevat

**Skills** (auto-activerend op natural-language triggers):
- `wiki-start` — sessie starten, oriëntatie op de wiki
- `wiki-ingest` — bronnen verwerken vanuit `raw/`
- `wiki-query` — kennisvragen beantwoorden via qmd + indexes
- `wiki-lint` — health check (broken links, orphans, stubs)
- `wiki-explore` — overview / graph / gaps verkennen

**Agents** (gespecialiseerd, oproepbaar via Task tool):
- `analysis-filer`, `contradiction-detector`, `cross-reference-sweeper`,
  `gap-detector`, `pdf-ingest-agent`, `source-cluster-tagger`, `stub-filler`

## Installeren

### Lokaal (vanuit deze repo)

```
/plugin marketplace add /Users/sanderrobijns/Documents/GitHub/claude-plugin-marketplace
/plugin install myrag-wiki@myrag-marketplace
```

### Via GitHub (na pushen)

```
/plugin marketplace add <user>/claude-plugin-marketplace
/plugin install myrag-wiki@myrag-marketplace
```

### In Claude Cowork

Voeg de marketplace toe aan team-`settings.json` zodat alle teamleden hem automatisch zien:

```json
{
  "extraKnownMarketplaces": {
    "myrag-marketplace": {
      "type": "github",
      "repo": "<user>/<repo>"
    }
  },
  "enabledPlugins": {
    "myrag-wiki@myrag-marketplace": true
  }
}
```

## Vereisten

- Obsidian-vault met de structuur beschreven in `CLAUDE.md` (raw/, wiki/, scripts/, index.md, log.md)
- qmd MCP-server geconfigureerd (zie `.mcp.json`)
- Python 3 voor `${CLAUDE_PLUGIN_ROOT}/scripts/regen-quick-indexes.py`
  (script wordt vanuit de vault root aangeroepen; vindt `wiki/` via cwd of via een vault-pad als argv[1])
