# Restore the prepared DrawMusic project

This private repository is initially seeded through GitHub's authenticated website. GitHub CLI's broad repo/workflow grant was declined; the owner approved the ChatGPT Codex Connector for only Imran-shisheo/DrawMusic. The transport parts hold the reviewed source checkpoint, not a Flutter implementation.

In a clean clone, run `python3 restore_bootstrap.py`. The helper verifies all part hashes, total size, full bundle SHA-256 and source commit, fetches the Git objects, and restores the reviewed project tree. Bootstrap transport files are removed from that new tree. Review the result, commit the restored setup to main and push it, then continue with the restored cloud/SETUP.md and cloud/FIRST-TASK.md. Do not overwrite or reset a nonempty unrelated tree.

For environment preparation: restore source first, read AGENTS.md, then run `bash scripts/setup-cloud-android.sh` on Linux x86_64. Source cloud/env.sh for later commands. Request owner approval if Android SDK license acceptance is required. Validate the actual toolchain before publishing the environment. Start the first development task only in the published cloud environment.

The complete local research is preserved on the Mac; unavailable provenance links in this compact checkout must not be fabricated. The final restored repository includes the PRD, original app specifications, 16 representative screenshots and independently generated source exports, feature roadmap, Android toolchain scripts and GitHub Actions APK workflow. Private phone captures and invalid runs remain on the owner's Mac.
