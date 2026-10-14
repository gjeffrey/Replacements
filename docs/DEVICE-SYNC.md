# Verify Apple's device sync

Apple documents that iCloud Drive keeps the personal dictionary current across devices: [iPhone Text Replacement guide](https://support.apple.com/guide/iphone/save-keystrokes-with-text-replacements-iph6d01d862/ios). This documents expected platform behavior; it does not certify that this app's private-API writes propagate.

## Guided test

1. Use a physical iPhone or iPad signed into the same Apple Account as this Mac, with iCloud Drive enabled. Avoid changing account settings during the test.
2. In Replacements, select **Verify Device Sync** and **Create a Sync Test Marker**. The unique `;rp-…` shortcut and recovery record are saved locally. The harmless marker is verified in the Mac's native library.
3. On the device, open Settings → General → Keyboard → Text Replacement. Find the exact shortcut with **Replacements sync check — first version**. Also type the shortcut followed by a space in Notes using Apple's keyboard. Record whether the list and typing behavior agree.
4. Only after observing creation, click **I See It on My Device — Test Edit**. The Mac changes the phrase to **Replacements sync check — edited version**. Wait until the edited phrase appears and expands on the device.
5. Click **I See the Edit — Test Delete**. Confirm the shortcut disappears from the device's Text Replacement list, and type it again in Notes.
6. Click **It's Gone — Finish Check** only after observing remote deletion. The result records the user observations, not an automatic cloud acknowledgement.

Sync is asynchronous; lack of immediate propagation is not proof of permanent failure. A list update without expansion may indicate app/keyboard caching. Keep “not yet observed” distinct from “failed.” Test after relaunching Notes and after reopening Settings if needed. Do not restart keyboardservicesd, rewrite the database, or reset the keyboard dictionary to force sync.

Use **Cancel & Clean Up** if you stop. It removes only the exact harmless marker on the Mac and labels remote cleanup unconfirmed. The record lives at `~/Library/Application Support/Replacements/sync-check.json`. It contains only the marker and observation times. If the app stops mid-test, relaunch and Refresh before advancing. A failed edit/delete does not advance the phase, allowing reconciliation rather than assuming success.

For release qualification, also make a harmless device-side edit and check that **Refresh** sees it on the Mac. Test macOS 15/26/27, at least one iPhone and iPad, cold launches, offline/reconnect, and simultaneous changes. Results must name exact OS versions and device observations.
