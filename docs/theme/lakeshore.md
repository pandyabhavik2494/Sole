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

Revised 2026-10-03 to be more vibrant at Bhavik's request; text contrast still meets 4.5:1.

Keep every token name so no call site changes. Values are `light / dark`.

| Token | Light | Dark | Source in the art |
|---|---|---|---|
| ink | 14262E | F1EADB | night teal / antler cream |
| muted | 55646A | A9B8BC | |
| background | F6EAD2 | 0E2F3D | birch / night sky |
| surface | FFFAF0 | 15404F | cards stay solid |
| line | E3D4B8 | 2B6274 | hairlines |
| accent | E8700F | FF9A2E | sun (steps, tint, buttons) |
| accentSoft | FFE0BF | 4F3010 | |
| good | 27782A | 6FD35A | pine |
| goodSoft | D6F2CC | 1A4A22 | |
| watch | 805300 | FFC93D | cattail (amber, never red) |
| watchSoft | FFE9B0 | 4A3810 | |
| heart | D11E48 | FF4F72 | loon eye |
| energy | E0401C | FF7043 | |
| oxygen | 2370C8 | 5AB0FF | lake |
| weight | 159A8C | 4FD8C6 | turtle shell |
| sleep | 3A4FCF | 8796FF | night |
| onAccent | 1A1206 | 1A1206 | |

New tokens:

| Token | Light | Dark | Use |
|---|---|---|---|
| accentText | A84F00 | FF9A2E | accent used as text or a text button (5.3:1 on surface) |
| outline | 14262E | 08141A | the bold Woodland line on cards, chips, the step ring |
| sky | F9E6C6 | 0E2F3D | top of the background gradient |
| skyLow | F3CF9E | 17506A | bottom of the background gradient |
| pine | 3F9A3A | 2E7A3A | scenery pines |
| ridge | 8FC4A0 | 175B66 | scenery hills |
| lake | 4F8FE0 | 1F5AA0 | scenery lake |

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
   `outline` stroke. Light mode draws the scenery at ~80% opacity, dark at ~95%.
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

- Accent as text uses `accentText`, not `accent` (light accent is under 3:1 on surface). Fills, the
  ring and the tab tint keep `accent`.
- Text on a `heart` fill (Connect Apple Health) uses `onAccent` in dark mode (5.7:1), not white.

- Text contrast: ink and muted on surface/background meet 4.5:1 in both modes (check muted on
  background in dark).
- Increase Contrast: outlines already help; no extra work needed.
