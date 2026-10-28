# Immersive visual regression references

These eight pixel references cover actual Flutter widgets in the current
Doodimo immersive design: dark Home/editor/export, cool-light Home/Settings,
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
