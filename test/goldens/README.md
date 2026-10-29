# Approved graphite visual regression references

These eight pixel references cover actual Flutter widgets in the current
approved Doodimo graphite/orange design: dark Home/editor/export, cool-light Home/Settings,
French 320 dp/200% editor, short landscape editor and RTL large-text language.
The explicit capture harness loads the bundled fonts/icons, uses declared
repository/audio fixtures and freezes decorative motion. Keyboard variants use
simulated insets. They do not prove native audio, motion or device performance.

The previous three rejected warm/editorial references are retained under
`docs/ui/progress-02/rejected-goldens/`; they are not active acceptance pixels.

Run `bash scripts/check-android.sh` for strict comparisons and the complete
screen matrix. Update only after rendering and inspecting the intentional
change, using `--update-goldens` with `UI_VISUAL_VERIFY=true` and
`UI_CAPTURE_IMMERSIVE=true`; never update references merely to silence a failure.
Actual native recordings and final Android gates remain independent evidence.

On29October the eight references were intentionally regenerated after inspecting the approved wholesale graphite redesign and its actual rendered widgets, including French200% and short-landscape transport captions. Prior navy references remain in Git, and an external working copy/hash manifest is preserved during review. Comparison thresholds and functional assertions are unchanged. This Linux update does not resolve the eight previously reported Mac-specific golden discrepancies.
