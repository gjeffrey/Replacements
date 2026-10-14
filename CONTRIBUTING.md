# Contributing

Small improvements are welcome: clearer native UI, useful plain-text templates, accessibility fixes, and tested compatibility with additional macOS versions.

Open an issue before a large change. Include the macOS version, build number, and whether you reproduced the problem in demo mode. Use sample data in screenshots and reports.

Run `./scripts/test.sh` and `./scripts/build-app.sh`, then launch with `--demo` to check the interface. Native mutation tests must be explicitly run on a disposable marker, preserve an initial snapshot, and clean up afterward. CI never writes to a user's replacements or contacts Apple sync services.

Preserve the current recovery behavior: a local backup before mutation, reviewed bulk actions, stale-data checks, and no automatic retries of ambiguous writes. SQLite access must remain read-only. Keep private framework access isolated in KeyboardBridge.

New templates should be useful as ordinary text and independently authored. Apple replacements cannot evaluate dates, scripts, clipboard macros, or cursor-position markers. Personal details must remain in the existing local profile, separate from gallery examples.

Contributions are licensed under the project's MIT license. Include complete notices for any approved MIT component; do not add AGPL or unlicensed source or assets.
