# Selected photo (Figma node 3:21820)

Journey label (annotation, NOT app UI): `04 · Capture / photo approval`

Icon colors inferred from render. All text Inter Regular. No bottom nav (only iOS home indicator, skip).

## Tree
Screen bg #f9fafb.

1. Status bar (system) — not built.
2. Header — column, padding top 10 / bottom 18 / horizontal 22, gap 12
   - Back button: row h44, min-w 64, gap 6: Lucide `arrow-left` 20px #111827 + `Back` 13 #111827.
   - Title `Ready for a closer look?` — 28, lh 1.15, ls -0.8, #111827
   - Subtitle `Selected photo · 1 image` — 14, lh 1.45, #6b7280
3. Content — column, padding top 6 / bottom 24 / horizontal 22, gap 20
   a. Selected photo — full width x h340, radius 18, BoxFit.cover. Asset `assets/images/selected_photo_groceries.png` (in app: the user's captured/picked image).
   b. Photo actions — row, gap 10, two Expanded buttons. Each: white bg, 1px #e5e7eb border, radius 10, min-h 52, padding h16 v14, row gap 10 centered, label 15.
      - Lucide `refresh-cw` 20px #111827 + `Replace / retake` #111827
      - Lucide `trash-2` 20px (renders dark #111827) + `Remove` in **#b91c1c** (destructive red)
   c. Guidance callout — bg #f3f4f6, no border, radius 10, padding 14, row gap 10, crossAxis start
      - Lucide `info` 19px #111827
      - Column gap 4, 13 lh 1.45:
        - `Send this photo for recognition` #111827
        - `Identify food uploads this image for analysis. Only the items you later confirm will be added to inventory.` #6b7280
   d. Disclaimer `A photo may suggest names and counts. It cannot tell exact weight, hidden ingredients, expiry or whether food is safe.` — 13, lh 1.45, #6b7280.
   e. Primary button — full width, bg #111827, 1px transparent border, radius 10, min-h 52, padding h16 v14, row gap 10 centered: Lucide `scan-line` 20px WHITE + `Identify food` 15 white.
   f. Secondary button `Choose from files` — full width, white bg, 1px #e5e7eb border, radius 10, min-h 52, padding h16 v14, centered 15 #111827.

Note: Figma reports Inter Regular 15 for these full-width buttons (h>=52), which differs from the shared "Semi Bold 13" primary-button token. Follow Figma here.

## Images
| slot | size | radius | asset |
|---|---|---|---|
| Selected photo | full width x 340, cover | 18 | `assets/images/selected_photo_groceries.png` — top-down spinach, 4 tomatoes in a square, bag of peas on a counter (1024x1024) |

## Interactions
- Back -> return to camera.
- Replace / retake -> camera/picker to replace image.
- Remove -> discard image, return to Scan & add.
- Identify food -> upload for recognition (loading state) -> Review detected items.
- Choose from files -> file picker to replace image.
