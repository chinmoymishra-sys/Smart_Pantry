# Camera capture (Figma node 3:21773)

Journey label (annotation, NOT app UI): `03 · Capture / camera`

Icon colors inferred from render. All text Inter Regular. No bottom nav on this screen (only the iOS home indicator, skip).

## Tree
Screen bg #f9fafb.

1. Status bar (system) — not built.
2. Header — column, padding top 10 / bottom 18 / horizontal 22, gap 12
   - Back button — row, h44, min-w 64, gap 6, centered: Lucide `arrow-left` 20px #111827 + `Back` Inter Regular 13 #111827. No background/border.
   - Title `Let’s see what you have` — 28, lh 1.15, ls -0.8, #111827
   - Subtitle `Food photo · Nothing is saved yet` — 14, lh 1.45, #6b7280
3. Content — column, padding top 6 / bottom 24 / horizontal 22, gap 20
   a. Mode chips — Wrap, spacing 8, run spacing 8 (single-select):
      - Unselected: white bg, 1px #e5e7eb border, radius 100 (pill), min-h 44, padding h14 v11, text 13 #111827.
      - Selected: bg #111827, 1px #111827 border, same size; row gap 6: Lucide `check` 14px white + text 13 white.
      - Chips: `Container` (unselected), `Single item` (unselected), `Groceries` (SELECTED).
   b. Camera viewfinder — full width x h352, radius 26, clipped. Stack:
      - Live camera preview filling it (BoxFit.cover). Design placeholder: `assets/images/camera_preview_groceries.png`. In app use the real CameraPreview.
      - Capture boundary: Positioned left 24, top 24, size 310x280 (at 358 width), transparent, 2px solid white border, radius 18.
      - Flash control pill: Positioned left 16, top 16; white bg, radius 100, padding 12, row gap 6: Lucide `zap-off` 18px #111827 + `Flash off` 12 #111827. Toggle (on state presumably `zap` + `Flash on`).
   c. Hint `Keep foods separate and labels visible. For a container, photograph the food and its label.` — 14, lh 1.45, #6b7280, text-align center, full width.
   d. Camera controls — row, gap 16, vertically centered:
      - Gallery: width 80, column gap 8, centered: Lucide `images` 26px #111827 + `Gallery` 12 lh 1.45 #111827 centered.
      - Shutter: Expanded, h76, centered child = circle 72x72, bg #111827, 6px #111827 border, Lucide `camera` 28px WHITE centered.
      - Flip: width 80, column gap 8: Lucide `switch-camera` 26px #111827 + `Flip` 12 #111827.
   e. Secondary button `Add manually instead` — full width, white bg, 1px #e5e7eb border, radius 10, min-h 52, padding h16 v14, centered text 15 #111827.

## Images
| slot | size | radius | asset |
|---|---|---|---|
| Viewfinder | full width x 352, cover | 26 (clip) | `assets/images/camera_preview_groceries.png` — top-down spinach bunch, 4 tomatoes, bag of peas on stone (1024x1024); placeholder for live camera |

## Interactions
- Back -> pop to Scan & add.
- Chips select capture mode; exactly one selected.
- Flash pill toggles flash.
- Shutter takes photo -> Selected photo screen.
- Gallery -> image picker -> Selected photo screen.
- Flip switches front/back camera.
- Add manually instead -> manual entry.
