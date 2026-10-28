# Original Library transition comparison

These owned-cloud-emulator captures cover the Library continuity correction. They predate the new Home scroll source `9f152e6`; they do not verify that source or physical frame pacing.

| Evidence | Before | After |
|---|---|---|
| Product | `7dada74e981a7352f71e5c37e13928556e3ab38a` | `c965431b171607db1f0ee556764016800f0b48ab` |
| Capture harness | `505776bb794583a3b4d9f250735b5a714c295e01` | `15eb9a8ad0a91203f36bfe0ff381e655570ab5dc` |
| Capture run | [40652396927](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40652396927) | [40655572848](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40655572848) |
| Original recordings/artifact | [12800174468](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40652396927/artifacts/12800174468) | [12802137412](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40655572848/artifacts/12802137412) |
| Independent reader | [40655572642](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40655572642) | [40662051765](https://github.com/Imran-shisheo/DrawMusic/actions/runs/40662051765) |
| Normal original MP4 |16.604822s /68frames |15.314044s /69frames |
| Reduced original MP4 |15.872433s /72frames |13.389878s /74frames |

Each subset passed44 actual hit-tested actions across two clips: root navigation, Library normal switches and rapid reversals, editor entry/Back, tools/paper open/Cancel and reduced motion. The harness asserts actual MediaQuery reduced-motion state at every action. Requested80ms rapid spacing is not a measured scheduling guarantee; actual monotonic action times are preserved in each artifact's transition JSON. This is the bounded transition subset, not the full23-shot capture, ambient-cycle or profile suite.

All four original MP4 tracks fully decode independently. The original files were not padded, retimed, repeated or interpolated. Recorder wall time and media PTS differ on the software emulator; low/sparse recorded frames do not establish app FPS, presentation drops or physical smoothness. Diagnostic reader labels remain `UNACCEPTED_DIAGNOSTIC_ONLY` for performance/full-suite acceptance, even though the strict transition capture and integrity gates passed.

## Inspected actual frames

[Before normal contact](before/01-root-navigation-contact.png) and [after normal contact](after/01-root-navigation-contact.png) each contain nine actual decoded frames, resized for the3×3 diagnostic image. Before frame33 at8.45329s shows a blank Library body while the dock remains on Library. After's sampled Library frames retain actual Drafts/Exports content. Sparse contacts cannot establish the state of every intermediate frame; meaningful pixel/interaction regressions separately cover continuity and retargeting.

[Before reduced-motion contact](before/06-reduced-motion-contact.png) and [after reduced-motion contact](after/06-reduced-motion-contact.png) show actual static/reduced state changes. Ink press feedback may remain visible; text and canvas geometry are stable in the sampled frames. Last sampled frames need not show the final Home state: the test's separate executed-action/readiness results establish that endpoint, not an invented video frame.

[Before Home](before/01-home.png) and [after Home](after/01-home.png) are original native screenshots, not redesigned mockups. App artwork is unchanged. Decorative ribbon phase and fixture state can differ; do not treat those differences as transition timing evidence.

Each directory contains a manifest with original byte lengths and SHA256. Contact PNGs are explicitly derived from actual original frames; Home PNGs are untouched originals. No diagnostic art is included in Flutter assets or user exports.

Normal MP4 SHA256: before `836b54d1423a8730ad57b21200c684391ef8b035594fe150beb39f37913bcc9c`; after `0503dc130929425af30075684eed99a8858655288863103a14937f50b439023e`. Reduced: before `65eda8208ff57b16f17bc441141124ce6dfec1cb3f732206b4eb04d796279288`; after `6ff9d1e84f135f02580ee3226c39feb71e4a4f8240a74f311c2c5297a2468daa`.
