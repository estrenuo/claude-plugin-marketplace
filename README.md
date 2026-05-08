# claude-plugin-marketplace

Een verzameling Claude Code / Cowork plugins van Estrenuo.

## Plugins in deze marketplace

- **[myrag-wiki](myrag-wiki/)** — Skills + agents voor het onderhouden van een Obsidian-based LLM wiki: ingest, query, lint, explore en start workflows bovenop de qmd MCP-server.

## Installeren

Voeg de marketplace toe en installeer een plugin:

```text
/plugin marketplace add estrenuo/claude-plugin-marketplace
/plugin install myrag-wiki@claude-plugin-marketplace
```

### In Claude Cowork

Voeg de marketplace toe aan team-`settings.json` zodat alle teamleden hem automatisch zien:

```json
{
  "extraKnownMarketplaces": {
    "claude-plugin-marketplace": {
      "type": "github",
      "repo": "estrenuo/claude-plugin-marketplace"
    }
  },
  "enabledPlugins": {
    "myrag-wiki@claude-plugin-marketplace": true
  }
}
```

Zie de README van elke plugin voor specifieke vereisten en configuratie.
