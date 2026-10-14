# Validation — October 12, 2026

## Environment

- macOS 27.0.1, build 26A434; Apple Silicon.
- Swift 6.3.1, Command Line Tools, macOS 26.4 SDK; deployment target macOS 15.
- Version 0.3.0: universal arm64/x86_64, Developer ID signed with Hardened Runtime.
- Apple notarization Accepted (`2dad5c7c-205e-47fb-859b-4cdc094fa8a8`); ticket stapled. Fresh extraction of the final zip passed strict signature, ticket, and Gatekeeper checks.

## Live native proof of concept

The read-only probe saw **26** live replacements. The native query callback returned zero while SQLite inspection found 26, establishing the need for a read-only fallback on this client.

A unique `;rp-…` test marker was added through KeyboardServices, modified through its native modify method, and deleted through its native remove method. Every result was read back and checked again after a short delay. Final contents matched the entire original list, including multiplicity, and remained at 26. No direct SQLite writes or global-defaults rewrites were used. Recovery snapshots are in the task's private working folder; personal replacement text is not included in this report or source package.

The running Hardened Runtime app also exercised its guided device-sync test. The user completed creation, editing and deletion observations in the app. Both known test markers are now absent from the native Mac list; its 26 original replacements still match the initial integration backup, including multiplicity. No test marker remains on this Mac.

## Automated checks

**34 tests passed**, including:

- JSON/CSV/Apple plist Unicode, quotes, newlines, dictionary words, and malformed input.
- Internal import conflicts, identical duplicates, ambiguous native pairs, and restore ordering/multiplicity.
- Snapshot round-tripping and 0600 permissions.
- All 32 templates render; required details, reusable profile merging, email/URL validation, unused shortcuts, persistence and corrupt-profile preservation.
- Stale baselines, failed backups, whole-plan validation, ambiguous replies without resending, and batch stops on concurrent arrivals or failed writes.
- Read-only native adapter: database bytes unchanged, tombstones excluded, missing database not created, incompatible schema rejected.

## Interface checks

The built app was launched in isolated demo mode and visually inspected. Search filtered seven rows down to one; inline editing saved a shortcut; a shared draft preserved and saved changes to both shortcut and phrase. The native mode loaded the actual library and the Verify Device Sync panel created a local marker successfully.

Additional product checks for release: end-to-end file-panel import/export, bulk review/restore, keyboard-only navigation, VoiceOver, long libraries, menu-bar quick add, and multiple supported macOS versions. Logic tests cover these data paths, but they are not a substitute for testing every user interaction.

The version 0.2.1 library and guided email form were inspected in isolated demo mode. Missing details disabled Add, a colliding shortcut received an unused suggestion, and the entered email appeared in the preview, was added, and was remembered in the demo profile. Profile reuse across templates and persistence are covered by core tests; GUI relaunch/prefill was not separately exercised.

The earlier signed 0.1.0 app also passed native UI add/edit/delete with a temporary marker. After template testing, a read-only audit again confirmed all 26 original native entries, including multiplicity.

## Device sync status

**Creation, editing and deletion were observed on the user's phone.** The latest complete guided test used `;rp-118e5819`. The app recorded these user confirmations:

- Creation: October 12, 2026 at 5:59:37 PM Pacific.
- Editing: October 12, 2026 at 6:01:59 PM Pacific.
- Deletion: October 12, 2026 at 6:02:06 PM Pacific.

The user also confirmed creation of the earlier `;rp-7e5f0e84` marker in chat. Both markers are gone from the Mac, and the original 26 replacements are preserved.

These are user-observed results for this Mac/phone pairing, not automatic cloud delivery acknowledgements or a guarantee across every macOS/iOS release. Phone OS version and actual text expansion were not separately specified. Device-to-Mac changes and iPad behavior have not been tested.

Apple documents dictionary sharing through iCloud Drive in the [iPhone guide](https://support.apple.com/guide/iphone/save-keystrokes-with-text-replacements-iph6d01d862/ios). The observed test now substantiates propagation of this app's native writes on this pairing.

## Remaining release requirements

Clean downloaded/quarantined installation on another Mac, Intel runtime testing, supported-OS matrix, phone OS version and reverse-direction/iPad checks, final product name, optional tip URL, source licensing terms and release/update decisions. Signing, notarization, the icon and template library are complete.

## Version 0.2.1 search regression check — October 13, 2026

In isolated demo mode, typing meeting filtered seven rows to one. Clear Search restored seven rows and returned focus to search. Adding the Received, thank you template then showed all eight rows, selected the new entry, and left search empty. No native replacements or personal details were changed by this check. All 31 tests passed again; both architecture slices built, and the final archive passed signature, ticket and Gatekeeper validation.

## Version 0.2.2 gallery check — October 13, 2026

All 33 tests passed (30 core, 3 native adapter). New checks confirm all gallery examples render, empty personal details still prevent saving incomplete templates, and searches match visible phrase content. The first Xcode test build hit Finder metadata on a test bundle; using a fresh temporary scratch directory resolved it. The test script accepts REPLACEMENTS_TEST_BUILD_DIR for this purpose.

The signed app's isolated demo gallery was visually inspected in All and Just for Fun categories. Cards show phrases and shortcuts without icons, names or descriptions. The email card displayed sample boilerplate while its setup sheet loaded the previously remembered demo email, proving gallery sample data did not replace saved user data. The check made no native mutations or profile changes. Universal compilation, notarization, stapling and fresh final-archive Gatekeeper verification passed. Prior phone-sync/native mutation results remain historical evidence; they were not repeated for this presentation-only update.

## Version 0.3.0 — October 13, 2026

The full suite passed: 31 core tests and 3 native adapter tests. The catalog has 59 templates. The new test verifies recurring meeting/help links normalize, reuse across templates, validate invalid URLs and preserve an existing booking link.

The final universal app built with Swift 6.4 and Xcode. The compact interface was inspected in isolated demo mode: no oversized main header/instructions, one-line table rows, separate Dictionary Words, selected-phrase preview/copy, and toolbar actions. Adding Appleseed through the word-only demo form produced one dictionary entry while Shortcuts remained at seven. All and Symbols template views were inspected. Repository screenshots show only demo/sample data. The updated icon was inspected at 128 pixels and in the sidebar. No live native mutations or profile changes were performed during these interface checks.

The final 0.3.0 zip passed strict signature verification, stapled ticket validation, Gatekeeper assessment and universal architecture inspection after fresh extraction. It includes the MIT notice. Public CI is configured to run tests and build an ad-hoc app on a macOS runner; CI does not run live KeyboardServices writes or notarization. Historical phone-sync/native-write evidence above remains specific to the original pairing and is not a guarantee for every supported OS.
