# Reviewed UI/UX tools and handoff

The owner authorized this repository's local UI/UX Pro Max setup on 28 October 2026. It supplements the existing Doodimo implementation; it does not authorize a new design direction, replacement assets, services, or a wholesale redesign.

## Pinned local skill

Upstream: [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/tree/28b3b8dee8c976df4fa3e94aed4e092ad43fcb03), commit `28b3b8dee8c976df4fa3e94aed4e092ad43fcb03` (26 October 2026). License: MIT, Copyright (c) 2024 Next Level Builder; the complete notice is retained in [.agents/skills/ui-ux-pro-max/LICENSE](../.agents/skills/ui-ux-pro-max/LICENSE).

The local entry point is [.agents/skills/ui-ux-pro-max/SKILL.md](../.agents/skills/ui-ux-pro-max/SKILL.md). Read it explicitly before applying the skill. Files being present does not prove automatic discovery, hot loading, a new connector, or access to Stitch.

This is a manually assembled Codex runtime bundle: all five canonical `src/ui-ux-pro-max/scripts/*.py` files and the complete canonical data tree, plus the upstream license. `SKILL.md` reproduces the reviewed Codex rendering of `templates/platforms/codex.json`, `templates/base/skill-content.md`, and `templates/base/quick-reference.md`, following the pinned `cli/src/utils/template.ts` substitutions. [PROVENANCE.json](../.agents/skills/ui-ux-pro-max/PROVENANCE.json) records every installed upstream file's source path, byte length, SHA-256 and Git blob SHA-1, along with rendering input hashes. No pre-existing skill was overwritten.

The upstream CLI, npm installer/updater, token/configuration handling, optional sibling skills, upstream tests requiring repository fixtures, gallery/screenshots and root catalog-refresh tools are excluded. No npm/bun/pip command or upstream installer was executed. Public GitHub reads established the commit, license and source layout; a bounded HTTPS archive of that exact commit supplied bytes. Its SHA-256 is `1f1046c5d8c72ac224f43c60389ce9e16f4cfc8ecb899e5fdb3589ab0fc3091b`; 48 selected archive files matched independently retrieved GitHub API blob hashes.

## Runtime review and checks

The five installed Python files were inspected for imports, data access, process execution, dynamic execution, credentials and persistence. Their 118 functions implement CSV/BM25 searches, deterministic closed JSON decision rules, formatting and local validation. Runtime code has no network client, subprocess/shell invocation, credential lookup, or `eval`/`exec` path. `urllib.parse` in the validator parses URLs without fetching them. The only environment lookup is `COLORTERM`, for terminal colors.

Ordinary searches read bundled local CSV/JSON files and print results. Explicit `--design-system --persist` can create Markdown under an explicitly chosen output directory; `--force` can replace existing files through atomic writes. Neither option was used during setup. These capabilities are retained upstream code, not permission to overwrite Doodimo's existing design documentation.

After review, offline checks passed: five Python files compiled, all 35 CSV files parsed (4,319 rows), four JSON catalogs parsed, and all 46 payload hashes/byte lengths matched the provenance manifest. CLI searches executed without installing dependencies or fetching assets. `focus not obscured --domain ux` returned two records, including Web WCAG AAA guidance; it does not prove native accessibility. `reduced motion --stack flutter` returned no match; its suggested `reduce` retry returned the const-widget/rebuild guideline, not a verified reduced-motion answer. Empty or off-topic results must remain explicit. Some Flutter rows describe 3.44.x; this app's pinned Flutter toolchain remains authoritative.

Example focused offline query, from the repository root:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 .agents/skills/ui-ux-pro-max/scripts/search.py \
  'rebuild' --stack flutter --json -n 2
```

Review copies and setup evidence are outside the Flutter repository at `/workspace/doodimo-review-artifacts/ui-ux-pro-max-review/`. This review covers the installed runtime and its file/persistence behavior, not a security audit of every upstream CLI, maintenance script, test, dataset recommendation or linked third-party site. These are tool setup checks, not product tests.

## Applying advice to Doodimo

User instructions, `AGENTS.md`, [DESIGN-SYSTEM.md](DESIGN-SYSTEM.md), [MOTION-SYSTEM.md](MOTION-SYSTEM.md) and the approved implementation govern the work. Preserve the Doodimo identity, existing semantic colors/fonts/original glyphs, motion and reduced-motion policy, accessibility, offline behavior, free creative features, application ID, saved data, native audio and export contracts. Do not import React/GSAP packages, replace original icons/fonts, or invent monetization because a generic catalog row suggests them. Check stack/version relevance before translating advice into Flutter.

Skill/catalog URLs are references, not shipping assets. External imagery, fonts, icons and generated HTML assets remain research-only until their exact bytes, origin and redistribution rights are reviewed and any approved shipping assets are vendored with provenance. Existing [ASSET-PROVENANCE.md](ASSET-PROVENANCE.md) remains authoritative for current shipping assets.

## Stitch access boundary

The selected cloud task has no callable Stitch MCP tools or Stitch credentials; this setup adds neither. The owner's separate Mac Stitch worker has a verified 16-tool connection. The supported handoff is **authorized selected Mac exports → Library file bytes → this same cloud task**, following [design/handoff/README.md](../design/handoff/README.md). It does not propagate Mac configuration, expose a Keychain, or grant direct cloud MCP access. No Stitch project access, design generation or export was performed as part of this setup.
