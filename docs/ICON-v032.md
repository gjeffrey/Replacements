# Icon — version 0.3.2

Three characters, **brb**, become three words, **be right back**. Blue abbreviation capsule, downward arrow, dark ink phrase, and a restrained white continuous-corner tile.

The direction was explored with the built-in image generation tool. The user approved the literal direction and requested actual San Francisco type and a more Apple-like treatment. The final original icon is drawn completely from paths and macOS's system font by [render-icon.swift](../scripts/render-icon-v032.swift), rather than editing or tracing the generated bitmap. The font resolved to `.AppleSystemUIFontDemi` on the development Mac. The PNG is rasterized on macOS; no font file is redistributed.

Regenerate on a Mac:

```sh
swift scripts/render-icon-v032.swift Resources/AppIcon.png
scripts/build-icon.sh
```

## Exploratory generation prompt

Use case: logo-brand. Asset type: production macOS app icon for Replacements, a utility for Apple native text replacements. Create one exquisite simple macOS app icon on transparent background, square 1024 canvas. A softly rounded porcelain-white macOS tile, centered with comfortable transparent outer margin, restrained tactile relief and very gentle shadow. Literal clear concept: a small blue rounded text lozenge in the upper third contains the exact dark-blue lowercase text "brb"; beneath it a graceful modest downward arrow; in the lower half the abbreviation becomes three larger clearly readable words, exact text "be right back", set on two centered lines "be right" then "back". Use beautiful clean SF-style humanist sans-serif typography, generous readable bold letterforms; text should be the design, not tiny decorative lines. Small abbreviation expanding into a few actual words is the primary visual story. Quiet cobalt blue and white palette, subtle dimensional blue lettering or crisp ink with tiny relief, refined first-party macOS system utility aesthetic. Make the composition legible at small Dock sizes and striking in its simplicity. No abstract ribbon, no keyboard illustration, no magic wand, no decorative sparkles, no additional labels, no extra letters. True transparent outside the rounded square tile.
