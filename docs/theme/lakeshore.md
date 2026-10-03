# Lakeshore theme

Sole's look, inspired by the colours and bold black outlines of a Woodland-style painting Bhavik shared
(dusk sky, setting sun, pines, lake). The icon and scenery are original drawings; nothing is copied
from the artwork. Preview: `docs/theme/lakeshore-preview.html` (also https://claude.ai/artifact/JTDzHYiurjYWhUnCJpSNtB).

## App icon

- `AppIcon-1024.png` (1024×1024, opaque RGB, no rounded corners) goes in
  `Sole/Assets.xcassets/AppIcon.appiconset/`, referenced by `"filename"` in the single universal
  1024 entry of `Contents.json`. iOS 26 builds the glass edge, dark and tinted versions itself.
- `AppIcon.svg` is the source drawing.

## Palette (`Shared/Palette.swift`)

Keep every token name so no call site changes. Values are `light / dark`.

| Token | Light | Dark | Source in the art |
|---|---|---|---|
| ink | 14262E | F1EADB | night teal / antler cream |
| muted | 55646A | A9B8BC | |
| background | EFE7D8 | 132C36 | birch / night sky |
| surface | FBF7EF | 1B3A46 | cards stay solid |
| line | D9CFBD | 2F5664 | hairlines |
| accent | D9761F | EE9A3A | sun (steps, tint, buttons) |
| accentSoft | F7DFC3 | 4A3420 | |
| good | 3F7A3A | 7DB86A | pine |
| goodSoft | DCEBD5 | 21402A | |
| watch | 8A5A0C | E6BE5A | cattail (amber, never red) |
| watchSoft | F3E3C0 | 3E3218 | |
| heart | B8283F | F25A6E | loon eye |
| energy | C2452A | F2774E | |
| oxygen | 3E6FA8 | 79A6DE | lake |
| weight | 4F8C84 | 7FC2B8 | turtle shell |
| sleep | 3E4F8F | 8C9BE0 | night |
| onAccent | 1A1206 | 1A1206 | |

New tokens:

| Token | Light | Dark | Use |
|---|---|---|---|
| accentText | A8550F | EE9A3A | accent used as text or a text button (4.9:1 on surface) |
| outline | 14262E | 08141A | the bold Woodland line on cards, chips, the step ring |
| sky | F4EADA | 132C36 | top of the background gradient |
| skyLow | E9D9BE | 1E4152 | bottom of the background gradient |
| pine | 4F7F45 | 2E5233 | scenery pines |
| ridge | 9DB3A2 | 173540 | scenery hills |
| lake | 7E9CC4 | 264A75 | scenery lake |

Also update `AccentColor.colorset` to the accent values.

## Background (`GlowBackground`)

Replace the three radial glows with a lakeshore scene, keeping the same API (`progress`) and the
Reduce Transparency fallback (flat `Palette.background`):

1. Vertical gradient `sky` → `skyLow`.
2. A sun glow: radial gradient of `accent` centred horizontally, low on the screen. It rises from
   about 80% to about 60% of the height and gets stronger as `progress` goes 0 → 1 (animated, and
   static under Reduce Motion).
3. Pinned to the bottom, about the lower third: a gentle `ridge` hill line, a few `pine` trees with
   wavy tiered edges, and a `lake` band with two faint wave lines. All shapes have a 1.5–2 pt
   `outline` stroke. Light mode draws the scenery at ~70% opacity, dark at ~95%.
   Draw with SwiftUI `Shape`s/`Path`, no image assets, so it scales to every device.

## Components

- Cards (`CardModifier`, `StatTile`, vitals rows card, Onboarding/Your Normal surfaces, Settings
  rows where they use `Palette.surface`): keep the solid fill, add a 2 pt `outline` stroke on the
  same rounded rect (`strokeBorder`). Chips get 1.5 pt.
- Step ring (`ProgressArc`): draw an `outline` ring under the track so the arc sits inside a bold
  black edge, like the art.
- Vitals dot markers: 1.5 pt `outline` stroke.
- Liquid Glass stays on chrome only (tab bar, + button, toolbar buttons, sheets). No custom glass on
  content. The tab bar tint is `Palette.accent`.
- Widgets: `containerBackground` uses `Palette.surface`; leave as is, it picks up new values.

## Accessibility

- Accent as text uses `accentText`, not `accent` (light accent is only 3:1 on surface). Fills, the
  ring and the tab tint keep `accent`.
- Text on a `heart` fill (Connect Apple Health) uses `onAccent` in dark mode (5.7:1), not white.

- Text contrast: ink and muted on surface/background meet 4.5:1 in both modes (check muted on
  background in dark).
- Increase Contrast: outlines already help; no extra work needed.
