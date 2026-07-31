# Settings Images

Screenshots shown in the About rail of the settings panel.

## Layout and naming

One folder per settings group, named after the group in `Modules/Settings.lua`:

```
Images/
└── transmog-window/
    ├── show-situation-values.tga
    └── show-situation-tooltips.tga
```

Files are `<setting-label>.tga`, kebab-cased.

## Format

- **TGA, 32-bit uncompressed.** WoW does not load PNG at runtime.
- Native screenshot dimensions are fine, no power-of-two padding needed.
- Trim to the feature itself and keep the dark UI backdrop, the About rail behind it is near black.

## Referencing one

Pass the path without the extension, relative to this folder, plus the source pixel size so the aspect ratio is preserved:

```lua
g:Toggle({
    image     = "transmog-window/show-situation-values",
    imageSize = { 571, 222 },
})
```

The panel resolves it against `addonFolder` and `imagesRoot`, both set in `BuildSettingsPanel`.

## Sources

PNG originals live in `images/` at the repo root. They are excluded from release packages and exist so a TGA can be re-exported if the UI changes.
