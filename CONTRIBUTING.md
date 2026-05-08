# Bijdragen aan claude-plugin-marketplace

Bedankt voor je interesse. Dit document legt vast hoe we plugins in deze
marketplace versioneren en taggen. Voor de bredere plugin-architectuur,
zie de [Claude Code plugin-docs](https://docs.claude.com/en/docs/claude-code/plugins).

## Plugin layout

Elke plugin leeft in een eigen subdirectory in de repo-root en bevat:

- `.claude-plugin/plugin.json` — manifest met `name`, `version`, `description`.
- `README.md` — installatie, configuratie, vereisten.
- Skills, agents, commands, hooks of MCP-config voor zover van toepassing.

Het manifest `.claude-plugin/marketplace.json` in de repo-root verwijst
naar elke plugin via een relatief `source`-pad.

## Versioning

We volgen [Semantic Versioning 2.0.0](https://semver.org/lang/nl/) per plugin.
Elke plugin in deze marketplace heeft een eigen versielijn in zijn
`.claude-plugin/plugin.json`.

### MAJOR / MINOR / PATCH voor plugins

Lees de generieke semver-regels op semver.org. Hieronder concretiseren we
wat *breaking*, *additive* en *fix* betekenen voor een Claude Code plugin.

**MAJOR (`X.0.0`)** — breaking changes voor bestaande gebruikers:

- Een skill, agent, command of hook is verwijderd of hernoemd.
- De trigger-conditie of `description` van een skill is zo gewijzigd dat
  bestaande prompts hem niet meer activeren.
- Een MCP-server is vervangen of de tool-prefix is hernoemd
  (bv. `mcp__qmd__` → `mcp__qmd-feat__`).
- Een meegeleverd template (zoals `templates/CLAUDE.md`) heeft een
  incompatibele structuur gekregen waardoor bestaande vaults breken.
- Vereisten zijn toegevoegd die bestaande installaties niet hebben
  (nieuwe externe dependency, nieuwe environment variable, etc.).
- Default-gedrag is gewijzigd op een manier die bestaande workflows breekt.

**MINOR (`x.Y.0`)** — backwards-compatibele toevoegingen:

- Nieuwe skill, agent, command of hook.
- Nieuwe optionele configuratie of nieuwe trigger-conditie naast bestaande.
- Nieuwe referentie-documentatie binnen een skill (`references/*.md`).
- Uitbreidende veranderingen aan templates die bestaande vaults niet raken.

**PATCH (`x.y.Z`)** — niets functioneels verandert voor de gebruiker:

- Bugfix in een prompt, skill-instructie of script.
- Verduidelijkende tekst, typo's, geformatteerde markdown.
- Interne refactor zonder gedragswijziging.
- Update van README, changelog of overige documentatie.

### Pre-1.0 regel

Plugins op `0.x.y` mogen MINOR-bumps gebruiken voor breaking changes.
Pas op `1.0.0` geldt het volledige contract. Een plugin gaat naar `1.0.0`
zodra de auteur expliciet stabiliteit toezegt.

## Git tags

We taggen per plugin, niet per repo. Het tag-formaat is:

```text
<plugin-name>/v<semver>
```

Voorbeelden:

```text
myrag-wiki/v0.1.0
myrag-wiki/v0.2.0
myrag-wiki/v1.0.0
```

Repo-wide tags (`v1.0.0` zonder plugin-prefix) gebruiken we niet. Dit
houdt versielijnen onafhankelijk zodra er meer dan één plugin bestaat.

## Release-workflow

Voor een plugin-release:

1. Bepaal het type bump (MAJOR / MINOR / PATCH) op basis van bovenstaande regels.
2. Update `version` in `<plugin>/.claude-plugin/plugin.json`.
3. Commit met een duidelijke boodschap, bijvoorbeeld:

   ```text
   myrag-wiki: bump to 0.2.0 (add wiki-export skill)
   ```

4. Tag de commit:

   ```bash
   git tag myrag-wiki/v0.2.0
   git push origin main --tags
   ```

5. Optioneel: schrijf een release-note op de bijbehorende GitHub release.

## Pull requests

- Werk op een feature-branch en open een PR tegen `main`.
- Houd PR's klein en gefocust op één plugin tegelijk.
- Beschrijf in de PR welk type bump (MAJOR / MINOR / PATCH) van toepassing is
  en waarom, zodat de tag na merge eenduidig vastligt.
- De versie-bump in `plugin.json` mag in dezelfde PR zitten of als
  losse follow-up commit op `main` direct na merge — kies één lijn en
  houd je daaraan.
