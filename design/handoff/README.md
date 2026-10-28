# Selected design handoff

Use `design/handoff/<date>-<flow>/` for owner-authorized, selected design material that is safe to commit publicly. This directory is a handoff convention, not an automatic import or approval to redesign Doodimo. No Stitch project access, generation or export has happened during setup.

The owner's separate Mac worker has the verified Stitch tools. This cloud task does not. The Mac worker exports only the selected, authorized artifacts to Library; this same cloud task receives the file **bytes** and reviews them against the approved brief and existing Flutter implementation. Do not copy Mac MCP configuration, credentials, Keychain material, bearer tokens or authenticated download URLs into the cloud task, Library notes or repository.

## Export and receive

1. The owner selects a flow/screen and authorizes the handoff. Do not enumerate unrelated private projects or generate a new design to fill missing context.
2. On the Mac worker, Stitch `get_screen` takes a resource name shaped `projects/{project}/screens/{screen}` and returns HTML/screenshot **file resource names**. Stitch `download_file` supplies raw HTML or base64 image bytes with MIME/dimensions. Raw Google download URLs require credentials; do not forward those URLs or credentials to the cloud.
3. Export the selected original screenshot/source bytes to Library. Where useful and authorized, include selected `designMd`, color, typography, spacing and component metadata. Include a small `SPEC.md` only when the owner supplies or approves a flow specification. Keep any confidential originals outside the public repository.
4. The cloud task consumes the authorized Library files, verifies byte lengths/SHA-256/MIME/image dimensions, and checks HTML/metadata for credentials, authenticated URLs, private account/project data, external dependencies and asset rights before staging. Do not run exported JavaScript, execute generated install commands or fetch linked assets automatically.
5. Stage only approved public-safe material under the dated flow directory. Review original images alongside the actual app. Implement only the selected approved scope; keep native behavior, data and tests intact.

## Directory contents

A handoff may contain:

```text
design/handoff/2026-10-28-home/
  SPEC.md                  # optional owner-approved scope/interaction notes
  screenshots/selected.png # selected original public-safe screenshot bytes
  source/selected.html     # optional reviewed public-safe source, inert input
  metadata.json            # optional selected sanitized design metadata
  provenance.json          # hashes, source/selection/license/review record
```

`provenance.json` should identify the selected flow, export date, originating tool, owner authorization reference, local filenames, byte lengths, SHA-256, MIME/dimensions and asset/license review status. Record whether bytes are original or a sanitized derivative and explain any transformation. Include project/screen identifiers only if the owner explicitly approves their public disclosure; otherwise use an approved local label. Do not publish private original identifiers or hashes merely to complete a template.

If HTML or metadata needs sanitizing, retain the original privately in Library and clearly label the reviewed derivative. Never present a derivative as an untouched original. Remote URLs or generated placeholders do not establish asset ownership or public redistribution permission. Research/reference media must stay out of shipping assets until separately licensed and reviewed.

## Implementation constraints

Read [UI-UX-TOOLS.md](../../docs/UI-UX-TOOLS.md), [DESIGN-SYSTEM.md](../../docs/DESIGN-SYSTEM.md), [MOTION-SYSTEM.md](../../docs/MOTION-SYSTEM.md) and the approved flow brief. Preserve Doodimo's established brand, original shipping assets, accessible controls and text, light/dark/reduced-motion behavior, offline storage, saved documents, free features, native audio and real export semantics. Flutter source remains the product; generated HTML is design input. Actual Android validation and owner-side iOS/physical QA remain separate evidence.
