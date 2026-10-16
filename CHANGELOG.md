# Changelog

## 0.3.4

- New graphic app icon: two blue character strokes become three word strokes through a curved substitution arrow.
- Original vector artwork, with the editable macOS renderer included.

## 0.3.3

- New Emoticons category with a local snapshot of 199 Messletters Popular faces and an additional eyes face.
- Larger face previews, a source link, and a focused setup form that lets each user choose their own shortcut before saving.
- Exact Unicode, combining marks, spaces and emoji variation selectors are preserved.

## 0.3.2

- Literal abbreviation-to-phrase icon, rendered with macOS's San Francisco system font.
- Removed the Dictionary Words section and word-only add form: current macOS KeyboardServices rejects empty-shortcut writes.
- Require shortcuts for new entries and reject unsupported word-only changes before any batch writes. Existing word-only entries remain visible and exportable.
- Show save failures inside add, template and review forms, with Refresh Library when reconciliation is needed; keep entered text and avoid a second delayed alert after cancel.

## 0.3.1

- Sparkle 2.10.0 updates from signed GitHub release assets.
- Check for Updates… in the app menu and Settings, with configurable automatic checks.
- Installation waits for in-progress saves and unsaved edits.
- Release tooling verifies the final notarized archive and generates the signed appcast using a Keychain-only signing key.
- Preserved full Sparkle license notices and signed embedded helpers.

## 0.3.0

- Compact main library doubles as a shortcut reference, with one-line rows, a selected-phrase preview and a copy action.
- Separate Dictionary Words section and focused word-add form.
- Import/export and backup actions move to the toolbar menu.
- Quick-add menu-bar icon becomes optional and is off by default.
- New sculptural blue expansion icon.
- 27 new native-compatible templates, including a Symbols category, bringing the library to 59.
- Remembered meeting-room and help-center links, separate from booking links.
- MIT-licensed public source project, build instructions and macOS CI.

## 0.2.2

- Gallery cards show example phrases and shortcuts, using John Appleseed-style sample data.
- Search matches preview text. Sample previews never fill personal setup drafts.

## 0.2.1

- Adding a template no longer fills the search field.
- Search has a clear button. Refresh remains on Command-R.

## 0.2.0

- Original icon, 32 guided templates and locally remembered personal details.

## 0.1.0

- Native read/add/edit/delete, search and inline editing, reviewed bulk actions, portable import/export, local history, conflict detection and a guided device-sync check.
