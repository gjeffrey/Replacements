# Icon — version 0.3.5

The selected Selection design shows San Francisco **ab** lettering inside a blue text-selection highlight, with two selection handles and three dark text strokes on a white continuous-corner tile.

The original artwork is rendered entirely from AppKit paths and the macOS system font; no font file or Apple icon asset is redistributed. Its editable source is [render-icon.swift](../scripts/render-icon.swift). The earlier Substitution renderer remains available as [render-icon-v034.swift](../scripts/render-icon-v034.swift).

Regenerate on macOS:

```sh
swift scripts/render-icon.swift Resources/AppIcon.png
scripts/build-icon.sh
```
