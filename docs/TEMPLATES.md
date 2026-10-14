# Template library and remembered details

Version 0.2.0 adds 32 templates in Essentials, Work, Everyday, and Just for Fun. The library includes contact details, signatures, introductions, scheduling links, common replies, and playful text faces.

## How it works

Choose a template, answer its specific questions, and review the exact phrase. The app suggests an unused shortcut, while allowing you to choose your own. Incomplete or conflicting templates cannot be added. Personal and work email addresses are stored separately.

Remember these details for other templates is enabled by default and clearly shown in the form. When enabled, only the fields used by that template are merged into the local profile; other stored fields are preserved. Uncheck it to use the entered information only for that replacement.

Your Details lets you edit individual values, clear them, or forget the whole profile. Drafts survive navigation. Changes to saved details affect future template instantiations, and do not silently rewrite existing native replacements. Added phrases continue to use Apple's native storage and sync.

Profile data is stored at `~/Library/Application Support/Replacements/personal-details.json`, with directory permissions 0700 and file permissions 0600. Demo mode uses a separate `Replacements-Demo` directory. Personal details are not included in this source package, sent to a custom service, logged, or stored in the template catalog. Only a phrase the user explicitly adds enters Apple's native library. A corrupt or unsupported profile is preserved and requires an explicit reset rather than being silently replaced.

## Inspiration

Community discussions repeatedly suggest contact details, reusable replies, personal links, and expressive symbols:

- [Shortcut for entering an email address](https://www.reddit.com/r/iphone/comments/1p3hzon/shortcut_for_entering_email_address/) — practical patterns for email, addresses, and phone numbers.
- [What text replacements do you use?](https://www.reddit.com/r/ios/comments/1et2ft0/what_text_replacement_do_you_all_use_for_your/) — multiple email accounts, links, symbols, and text faces.
- [What do you use text replacement for?](https://www.reddit.com/r/ios/comments/1lsx3fk/what_do_you_use_text_replacement_for/) — repeated sentences and frequently shared links.

These are inspiration sources, not imported code or third-party snippet packages. Phrase copy is authored for this app; conventional Unicode/text faces are included as short common expressions. The catalog uses a consistent semicolon prefix to reduce accidental expansion and adjusts a suggested shortcut when the native library already uses it.

## Validation

Tests cover full catalog rendering, missing information, reuse of one remembered email across multiple templates, partial profile merging, non-recursive substitution of user-provided content, URL normalization and email validation, shortcut collisions, persistent storage with private permissions, and corrupt-file preservation. UI checks use isolated demo data rather than the user's native personal information.

## Preview gallery in 0.2.2

Cards show example phrase text, with a smaller suggested shortcut and Personalize/Add affordance. Icons, visible card names and descriptions are removed. Names remain in accessibility labels and setup forms. Search finds the visible example phrase as well as category, shortcut and template metadata. Category filters and guided setup remain available.

Gallery examples always use a consistent sample identity, independent of the user's saved personal details. Opening a template seeds its draft from saved personal details only. The sample identity is never merged into the local profile or used as a fallback when adding an incomplete template.

Apple sources:

- [WWDC20: Meet Face ID and Touch ID for the web](https://developer.apple.com/videos/play/wwdc2020/10670/) uses John Appleseed and john.appleseed@example.com. These exact sample values are used in the gallery.
- [Apple Contacts documentation](https://developer.apple.com/documentation/contacts) uses John Appleseed, (408) 555-0126, and One Apple Park Way in its contact-building example. The gallery follows these contact examples.
- [Apple's Text Replacement guide](https://support.apple.com/en-au/guide/iphone/iph6d01d862/27/ios/27) demonstrates omw and On my way!, which is already part of the catalog.

The work email, Example Company/Designer, social handle and example.com URL paths are app-authored adaptations of the sample-data convention, not claimed as exact Apple-provided examples for a template gallery. No Apple source implementation or visual assets were copied.

## Expanded library in 0.3.0

The catalog now contains 59 templates: the original 32 plus 27 additions. New templates include recurring meeting-room links, help-center links, short named sign-offs, meeting notes and agenda outlines, project briefs and bug reports, requests for context/screenshots/missing attachments, rescheduling, two everyday replies, and 11 writing/keyboard symbols. A Symbols category keeps the glyphs easy to find. Hovering a symbol shows its name; its name is also available to accessibility tools and search.

The recurring meeting-room link is stored separately from the existing calendar-booking link. The help-center link has its own remembered field. Both use the existing local profile and URL validation, and are reused across multiple templates. Older profiles remain compatible; the new fields start empty. Gallery examples remain independent of personal data.

Sources consulted on October 13, 2026:

- [TextExpander users' most expanded snippets](https://community.textexpander.com/t/what-are-you-most-expanded-snippets/510): named sign-offs, repeated links, dividers, status-note headings and spelling corrections.
- [TextExpander community's snippet ideas](https://community.textexpander.com/t/what-should-you-actually-turn-into-a-text-snippet-here-are-some-ideas/406): office messages, meeting-note outlines and reusable customer-support patterns.
- [TextExpander email use cases](https://textexpander.com/blog/email-snippets-examples): rescheduling, requests for additional context and frequently used replies. The app's prose is independently authored rather than importing these snippets or their macro syntax.
- [Raycast users' favorite snippets on Reddit](https://www.reddit.com/r/macapps/comments/1dlh2m4): recurring meeting links and Mac keyboard symbols.
- [Native text-replacement notes/Markdown use cases](https://www.reddit.com/r/ObsidianMD/comments/162jrfb): reusable plain-text outlines. App-specific smart punctuation can still affect inserted Markdown.

All additions save ordinary text. Outline sections are intentionally blank and filled after expansion. There is no automatic date calculation, clipboard interpolation, expansion-time form, script execution, rich-text insertion or cursor placement. Those commercial-tool features need a separate expansion engine and are not represented as supported native templates. No imported TextExpander/Raycast packages, AGPL/unlicensed code or source assets were used.

## Emoticons in 0.3.3

The Emoticons category contains a static snapshot of all **199** entries in the [Messletters Popular emoticons](https://www.messletters.com/en/emoticons/) list fetched on October 13, 2026, plus the requested eyes face, for 200 faces and 259 total templates. The requested hug `(っ◕‿◕)っ` is included in the Popular snapshot.

Only the short conventional Unicode expressions were copied. Display labels and setup copy are app-authored; website HTML, CSS, JavaScript, click counts, ranking logic and other source assets are not included. The app never fetches this collection at runtime. A link credits the source in the category footer.

Cards preview the face and offer Add. Setup starts with an empty, focused shortcut field, and preserves the exact expression in a larger preview. The user must choose a nonconflicting shortcut before a native replacement is added. No profile fields are required or remembered. Existing template categories keep their suggested shortcuts. Tests check all face renderings byte-for-byte, the requested expressions, empty-shortcut rejection before a snapshot, and successful isolated saving with a custom shortcut.
