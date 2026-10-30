# Tweaky brand

**Idea:** a lowercase *t* whose crossbar is a tilde (~), the sign for "adjust". Tweaky tweaks your text.

## Files

| File | Use |
|---|---|
| `tweaky-symbol.svg` | Master symbol, black, filled outlines (no strokes, no text) |
| `tweaky-symbol-white.svg` | On dark or indigo backgrounds |
| `tweaky-symbol-indigo.svg` | One-colour brand version |
| `tweaky-app-icon.svg` | macOS app icon source (Apple 824/1024 grid); rendered to `Resources/AppIcon.png` |
| `tweaky-menubar.svg` | Menu bar glyph; rendered to `Resources/MenuBarIcon.png` (18 px) and `@2x` (36 px), used as a template image |

## Colour

| Name | HEX | RGB |
|---|---|---|
| Tweaky Indigo | `#4F3FE6` | 79 63 230 |
| Ink | `#1F1F1F` | 31 31 31 |

The UI is monochrome (ink on white, hairline borders, Google Sans). Indigo is the single accent: the app icon
background and the shortcut badge. No gradients, shadows or glows anywhere.

## Rules

- Clear space: at least the stem width (26/256 of the symbol) on every side.
- Minimum size: 16 px. The symbol is tested at 16, 20, 24 and 32 px.
- Approved backgrounds: white, black, Tweaky Indigo, macOS window materials.
- Do not: rotate, stretch, outline, add shadows or glows, recolour the parts separately, or add sparkles.

## Construction

256 grid, weight matched to Google Sans Regular. Stem 26 wide with round caps; hook is a quarter ring
(radii 35/61). Tilde is two half rings (centreline radius 28), drawn 22 wide, slightly thinner than the stem as an
optical correction. App icon: flat `#4F3FE6` on the Apple 824/1024 grid, glyph scaled 2.5x and centred optically.
