# Icon — version 0.3.4

The selected Substitution design uses two short blue character strokes, three longer dark word strokes, and a single curved blue arrow. It sits on the same restrained white continuous-corner tile as the earlier icon.

The artwork consists entirely of original AppKit paths, with no image-generation step, embedded font, or copied Apple asset. The source remains editable in [render-icon.swift](../scripts/render-icon.swift). A 1024-pixel master and the standard macOS icon sizes are included. The master was inspected at 512 pixels and at a 64-pixel Dock size during concept review.

Regenerate on macOS:

```sh
swift scripts/render-icon.swift Resources/AppIcon.png
scripts/build-icon.sh
```

The earlier San Francisco abbreviation icon can be regenerated with [render-icon-v032.swift](../scripts/render-icon-v032.swift).
