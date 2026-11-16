# Scan & add (Figma node 3:21712)

Journey label (annotation, NOT app UI): `02 · Capture / choose a method`

Icon colors are inferred from the render (SVG fills were not inspected): default #111827 unless noted.
All text in this frame is Inter Regular unless noted.

## Tree
Screen bg #f9fafb. Vertical column, no gaps between top-level sections.

1. Status bar (system; h48, px26) — not built.
2. Header — column, padding top 10 / bottom 18 / horizontal 22, gap 12
   - Title `What’s coming home?` — Inter Regular 28, line-height 1.15, letter-spacing -0.8, #111827
   - Subtitle `Add a little or a whole grocery haul.` — Inter Regular 14, lh 1.45, #6b7280
3. Content — column, padding top 6 / bottom 24 / horizontal 22, gap 20 (min-height 642, so it fills down to the nav)
   a. Hero photo — full width x h192, radius 18, BoxFit.cover. Asset: `assets/images/groceries_counter_angled.png`.
   b. Capture methods — column, gap 12. Four identical tappable cards:
      card = white bg, 1px #e5e7eb border, radius 18, padding 16, row gap 14, vertically centered:
      [Lucide icon 25px #111827] [Expanded column gap 4: title Inter Regular 15 lh 1.45 #111827 / subtitle Inter Regular 13 lh 1.45 #6b7280] [Lucide `chevron-right` 18px #111827]

      | icon | title | subtitle |
      |---|---|---|
      | `camera` | `Take a photo` | `Containers, one item or market groceries` |
      | `image-up` | `Upload a photo` | `Choose from your gallery or files` |
      | `scan-barcode` | `Scan barcode / QR` | `Look up a packaged product` |
      | `pencil-line` | `Add manually` | `You know it best. No scan needed.` |
   c. Guidance callout — bg #f3f4f6, NO border, radius 10, padding 14, row gap 10, crossAxis start
      - Lucide `info` 19px #111827
      - Column gap 4, both Inter Regular 13 lh 1.45:
        - `You always get the final say` #111827
        - `Review and edit every item before it goes into your pantry. We’ll ask for camera or photo access only when you use it.` #6b7280
4. Bottom nav (shared) — white bg, top border 1px #e5e7eb, padding top 12 / bottom 8 / horizontal 12, gap 12. Row of 4 equal destinations (gap 4; each min-h 48, column gap 5, centered): icon 22px + label 11px.
   - `house` `Overview` — inactive: Inter Regular 11, #6b7280 text + icon
   - `scan-line` `Scan/Add` — ACTIVE: Inter Bold 11, #111827 text + icon
   - `refrigerator` `Inventory` — inactive
   - `utensils` `Meals` — inactive
   - Note: this frame shows exactly 4 destinations (label `Scan/Add`); there is no separate "Add" tab here. The 124x4 #111827 home-indicator bar is iOS chrome (skip).

## Images
| slot | size | radius | asset |
|---|---|---|---|
| Hero | full width (358 in a 402 frame) x 192, cover | 18 | `assets/images/groceries_counter_angled.png` — spinach bunch, 4 tomatoes, bag of peas on a light counter, angled shot (1376x768) |

## Interactions
- Take a photo -> Camera capture screen (request camera permission only now).
- Upload a photo -> system gallery/file picker -> Selected photo screen.
- Scan barcode / QR -> barcode scanner flow.
- Add manually -> manual add form (Edit detection-style).
- Bottom nav switches tabs; Scan/Add is current.
