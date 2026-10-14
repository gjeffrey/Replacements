# Updates with Sparkle and GitHub

Sparkle 2.10.0 is pinned through Swift Package Manager, with its binary checksum and complete license notices preserved. The app reads `https://raw.githubusercontent.com/gjeffrey/Replacements/main/appcast.xml`. Each feed item points at the corresponding GitHub release's `Replacements.zip`.

The release includes Sparkle.framework and its updater/XPC helpers, re-signed from the inside out with the app's Developer ID identity. Production builds keep Hardened Runtime and library validation; no runtime exception is added. Local ad-hoc builds omit Hardened Runtime to allow loading the framework for development.

The Ed25519 signing key stays in the macOS Keychain under the Sparkle account `com.gabrieljeffrey.replacements`. Only its public key is in Info.plist. Do not export it into source, logs, a feed, or GitHub secrets. The feed signs the exact final stapled archive, never the pre-notarization archive.

Automatic checks start enabled, can be disabled in Settings, and do not send Sparkle's optional system profile. Automatic downloads/installation are disabled: the user chooses to install. Manual checks are available in the application menu and Settings. Checks and relaunch wait for in-progress writes, unsaved row/profile drafts and open editor/review sheets. Normal demo runs and command-line builds do not start the updater.

## Publish another update

1. Increase both CFBundleShortVersionString and CFBundleVersion in Resources/Info.plist. Sparkle compares the monotonically increasing build number, not the GitHub tag. Run the tests.
2. Build a signed universal app using scripts/build-app.sh and the existing Developer ID identity. Use a fresh REPLACEMENTS_OUTPUT_DIR for each notarization submission.
3. Notarize and staple with scripts/notarize.sh and the local notarytool Keychain profile.
4. Generate a feed from the final zip:

   ```sh
   ./scripts/generate-update.sh /path/to/final/Replacements.zip /path/to/appcast.xml /path/to/release-notes.md
   ```

   The script verifies nested signatures, Developer ID, the stapled ticket and Gatekeeper acceptance, then checks that the Keychain public key matches the app. It invokes Sparkle's official generator; no private key is placed in a file. Set REPLACEMENTS_SPARKLE_BIN to the official Sparkle bin directory if the package artifact tools are in another build directory.
5. Commit/tag the matching application source. Upload the exact signed zip as Replacements.zip to a GitHub release matching v plus the short version. Publish the release and verify its download digest.
6. Only after the release asset is publicly available, copy the generated appcast.xml to the repository root, commit and push it to main. Keep existing release assets immutable: their archive signatures would be invalidated by rebuilding or replacing the zip.
7. Check the live feed and run a manual update check. CI validates the source and builds an ad-hoc app; it deliberately has no Developer ID/notarization/Sparkle private keys.

The feed includes only releases explicitly promoted by this process. GitHub prerelease status alone does not govern Sparkle delivery. The current feed uses full archives without binary deltas; future updates retain the same bundle identifier and signing/public-key continuity.

## Initial install

Versions through 0.3.0 have no updater. Install 0.3.1 manually once. Later releases can be discovered and installed in the app. No separate website, account, custom server or sync service is required.

## Verified 0.3.1 bootstrap

The public feed, GitHub archive digest, Ed25519 verification and modified-archive rejection were checked. A lower-version signed copy updated itself to the notarized 0.3.1 payload and relaunched in a temporary directory; a read-only audit confirmed native replacement contents stayed unchanged. This test used a modified, signed lower build as recommended for development; the target archive was the actual notarized GitHub release. Both source and feed CI runs passed.

Official references: [Sparkle setup](https://sparkle-project.org/documentation/), [programmatic integration](https://sparkle-project.org/documentation/programmatic-setup/), and [publishing updates](https://sparkle-project.org/documentation/publishing/).
