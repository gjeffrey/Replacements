# Direct-distribution release

Version **0.3.0** is signed with Developer ID Application: Gabriel Jeffrey (VDNJRV3PR9), bundle ID `com.gabrieljeffrey.replacements`, Hardened Runtime, and universal arm64/x86_64 binaries. Apple accepted notarization submission `2dad5c7c-205e-47fb-859b-4cdc094fa8a8`. The ticket is stapled, and a fresh extraction of the final `Replacements.zip` passed strict signature verification, ticket validation and Gatekeeper assessment. Release receipts are in `release/0.3.0/`. Native signed-app add/edit/delete and user-observed phone sync were verified on this Mac/phone pairing.

The following steps reproduce the release; the final package has already completed them. Credentials remain in the macOS Keychain and are not included in source or archives.

Apple's official guidance: [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [Hardened Runtime](https://developer.apple.com/documentation/security/hardened-runtime).

1. Install the owner's Developer ID Application certificate/private key, and choose a stable reverse-domain bundle identifier that the owner controls. Nothing in the repository stores signing credentials.
2. Run tests and build a signed universal app if supporting both Apple Silicon and Intel:

   ```sh
   REPLACEMENTS_BUNDLE_ID='your.owned.domain.replacements' \
   REPLACEMENTS_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
   ./scripts/build-app.sh --universal
   ```

3. Run the same native read/add/edit/delete test from the signed app and observe device sync. Dynamic Apple framework loading is isolated; the app has no App Sandbox entitlement, no private entitlement, and no Hardened Runtime exceptions.
4. Configure an existing notarytool keychain profile through Apple's instructions. Then:

   ```sh
   REPLACEMENTS_NOTARY_PROFILE='your-existing-keychain-profile' ./scripts/notarize.sh
   ```

   The script submits once, saves the JSON result, requires status Accepted, staples and validates the ticket, checks Gatekeeper assessment, and creates a final zip. If submission status is ambiguous, recover its ID/result with notarytool before resubmitting. If rejected, fetch the submission log, fix the cause and repeat validation; do not assume private API use is acceptable merely because the app builds.

5. Test the downloaded/quarantined zip on a clean Mac, with the normal Finder/Gatekeeper path and no quarantine removal. Verify the native integration without developer tools. Test an Intel Mac before claiming Intel support.
6. Before public release, choose the final product name, website, optional tip destination, user support/recovery instructions, source-code licensing terms and update strategy. No updater or external service exists in this preview.

A notarization ticket is a distribution check, not an Apple-supported contract for KeyboardServices. Maintain per-OS integration fixtures and an unsupported-platform state that disables writes when selectors or schema checks fail. Do not market “reliable iCloud sync” until device observations substantiate it.

Source is published under MIT at https://github.com/gjeffrey/Replacements. The signed 0.3.0 archive is attached to the corresponding GitHub release. Signing credentials stay in the macOS Keychain and are never stored in the repository.
