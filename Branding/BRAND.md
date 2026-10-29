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
| Icon gradient top | `#6353F2` | 99 83 242 |
| Icon gradient bottom | `#3F30D4` | 63 48 212 |

Use the indigo sparingly in the UI: primary action only. The gradient is for the app icon only.

## Rules

- Clear space: at least the stem width (36/256 of the symbol) on every side.
- Minimum size: 16 px. The symbol is tested at 16, 20, 24 and 32 px.
- Approved backgrounds: white, black, Tweaky Indigo, macOS window materials.
- Do not: rotate, stretch, outline, add shadows or glows, recolour the parts separately, or add sparkles.

## Construction

256 grid. Stem 36 wide with round caps; hook is a quarter ring (radii 30/66). Tilde is two half rings
(centreline radius 28), drawn 32 wide, slightly thinner than the stem as an optical correction.
