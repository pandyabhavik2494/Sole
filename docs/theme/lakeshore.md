# Lakeshore theme

Sole's look, inspired by the colours and bold black outlines of a Woodland-style painting Bhavik shared
(lake-blue sky, setting sun, pines, lake). The icon and scenery are original drawings; nothing is copied
from the artwork. Preview: `docs/theme/lakeshore-preview.html` (also https://claude.ai/artifact/JTDzHYiurjYWhUnCJpSNtB).

## App icon

- `AppIcon-1024.png` (1024×1024, opaque RGB, no rounded corners) goes in
  `Sole/Assets.xcassets/AppIcon.appiconset/`, referenced by `"filename"` in the single universal
  1024 entry of `Contents.json`. iOS 26 builds the glass edge, dark and tinted versions itself.
- `AppIcon.svg` is the source drawing.

## Palette (`Shared/Palette.swift`)

Revised 2026-10-03 at Bhavik's request: more vibrant, and lake blue replaces teal as the main colour (teal read too dark). Text contrast still meets 4.5:1.

Keep every token name so no call site changes. Values are `light / dark`.

| Token | Light | Dark | Source in the art |
|---|---|---|---|
| ink | 132743 | F2F6FC | deep lake navy / pale sky |
| muted | 52627A | B5C7DE | |
| background | E3EEFB | 163866 | lake sky |
| surface | FFFDF8 | 1B4274 | cards stay solid |
| line | D3DFEE | 2E5C96 | hairlines |
| accent | E8700F | FF9A2E | sun (steps, tint, buttons) |
| accentSoft | FFE0BF | 4F3010 | |
| good | 27782A | 74D85F | pine |
| goodSoft | D6F2CC | 1A4A22 | |
| watch | 805300 | FFC93D | cattail (amber, never red) |
| watchSoft | FFE9B0 | 4A3810 | |
| heart | D11E48 | FF6B88 | loon eye |
| energy | E0401C | FF7043 | |
| oxygen | 2370C8 | 7CC0FF | lake |
| weight | 159A8C | 4FD8C6 | turtle shell |
| sleep | 3A4FCF | 9AA6FF | night |
| onAccent | 1A1206 | 1A1206 | |

New tokens:

| Token | Light | Dark | Use |
|---|---|---|---|
| accentText | A84F00 | FFA445 | accent used as text or a text button (5.3:1 on surface) |
| outline | 132743 | 0A1630 | the bold Woodland line on cards, chips, the step ring |
| sky | DCEBFC | 163866 | top of the background gradient |
| skyLow | B9D5F5 | 2459A0 | bottom of the background gradient |
| pine | 3F9A3A | 2E7A3A | scenery pines |
| ridge | 9CC3A8 | 1E4A85 | scenery hills |
| lake | 3F86DB | 2F6FC8 | scenery lake |

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

## Animals (added 2026-10-03)

Bhavik asked for the painting's animals in the background. These are new drawings of the same kinds
in the bold outlined style, not traced figures: eagle, moose, bear, loon, turtle, fish.

- Code: `docs/theme/LakeshoreAnimals.swift` (generated from `animals.json`, the shape source) goes in
  `Sole/Views/Components/`. Each animal is a list of filled parts; `draw(in:rect:outline:flipped:)`
  draws it into a `Canvas` with `Palette.outline` strokes. Animal fills are fixed colours (not
  palette tokens), same in light and dark.
- Placement, in the preview's 300×300 bottom scene (ridge line ≈ y 174–180, lake surface ≈ y 192–198);
  translate to the real scene's geometry so the land animals stand on the ridge and the loon floats
  on the lake surface:
  - eagle: x 168, y 20, width 96, flying left, in the sky above the ridge
  - moose: x 56, feet on the ridge, width ≈ 92
  - bear: x 188, feet on the ridge, width ≈ 78
  - loon: x 118, body sitting on the lake surface, width ≈ 60
  - fish: x 22 just under the surface (width 40); a second smaller fish at x 120 facing right (width 30)
  - turtle: x 196 just under the surface, width 30
  - Draw order: eagle, ridge + pines, moose and bear, lake + waves, fish and turtle (90% opacity), loon.
- Keep it quiet: the animals share the scenery's opacity (80% light / 95% dark) and never sit behind
  the headline. They are static (no motion), hidden for VoiceOver, and dropped with Reduce
  Transparency like the rest of the scene. On narrow widths keep the land animals clear of the pines.
