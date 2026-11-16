# Inventory saved (Figma 3:22407)

Journey label (annotation, NOT app UI): `11 · SAVE / EXPLICIT CONFIRMATION` (source text "11 · Save / explicit confirmation", 12px Inter Regular, uppercase, tracking 0.5, bg #f3f4f6, radius 10, padding 12x10).

Frame: mobile screen, bg #f9fafb, min-height 874. Status bar (9:41, 15px; 48px tall, h-padding 26) is an annotation/system UI.

## Tree (top-down)

### Header (column, gap 12, padding top 10 / bottom 18 / horizontal 22)
- **Back navigation** (button): row, gap 6, height 44, min-width 64, vertically centered.
  - Icon `arrow-left` 20x20, #111827
  - "Back": Inter Regular 13, line-height normal, #111827
- **Title** "A good haul, all sorted.": Inter Regular 28, line-height 1.15, tracking -0.8, #111827
- **Subtitle** "Review complete · 3 confirmed items added": Inter Regular 14, line-height 1.45, #6b7280

### Content (column, gap 20, padding top 6 / bottom 24 / horizontal 22, min-height 606)
1. **Success block** (column, centered, gap 18, full width)
   - Confirmation mark: circle 76x76, bg #f3f4f6, radius 100; centered icon `check` 36x36, #111827
   - Food photograph: full width x 204 height, radius 18, BoxFit.cover -> `assets/images/haul_spinach_tomatoes_peas.jpg`
2. **Summary card** (standard card: white, 1px #e5e7eb, radius 18, padding 16; column gap 12). Three detail rows, each a row with gap 12:
   - Label column fixed width 140: Inter Regular 13, lh 1.45, #6b7280
   - Value column (expanded): Inter Regular 13, lh 1.45, #111827
   - Rows (verbatim):
     - "Spinach" | "150 g · Fridge"
     - "Tomatoes" | "4 pieces · Fridge"
     - "Green peas" | "300 g · Freezer"
3. **Explanation text**: "You confirmed the identity and count of all 3 items. Your pantry now has 12 unique food items." Inter Regular 14, lh 1.45, #6b7280, full width.
4. **Updated storage counts**: row, gap 8, three equal (Expanded) tiles. Each tile: bg #f3f4f6, radius 10, padding 12, no border. Text centered Inter Semi Bold 12, lh 1.45, #111827. Strings are label + TWO spaces + count:
   - "Freezer  2", "Fridge  6", "Pantry  4"
5. **Primary action** "View inventory": full width, min-height 52, padding 16x14, bg #111827, radius 10 (1px transparent border), text Inter Regular **15** white, centered. (Note: 15px Regular here, not the 13px Semi Bold of the shared small button.)
6. **Secondary action** "What can I cook now?": full width, min-height 52, padding 16x14, bg white, 1px #e5e7eb border, radius 10, text Inter Regular 15 #111827, centered.

### Bottom navigation (shared)
White bg, top border 1px #e5e7eb, padding top 12 / bottom 8 / horizontal 12, column gap 12. Destinations row gap 4, four equal items (column, gap 5, min-height 48, centered):
- `house` 22 "Overview" (inactive)
- `scan-line` 22 "Scan/Add" (inactive) — note this frame shows a single combined "Scan/Add" item, not separate Scan and Add
- `refrigerator` 22 "Inventory" (**active**)
- `utensils` 22 "Meals" (inactive)
Labels 11px: inactive Inter Regular #6b7280 (icon #6b7280); active Inter **Bold** #111827 (icon #111827).
Home indicator: 124x4, #111827, radius 100 (system annotation; can be omitted in app).

## Images
| Slot | Size | Radius | Asset |
|---|---|---|---|
| Food photograph under check mark | full width (≈346 on 390 frame) x 204, cover | 18 | `assets/images/haul_spinach_tomatoes_peas.jpg` (spinach bunch, 4 tomatoes, bag of frozen peas on beige stone; 1376x768 JPEG) |

The photo should ideally be the user's scanned photo (dynamic); the asset is the static placeholder.

## Interactive intent
- Back: pop to the previous (review) screen.
- View inventory: navigate to Inventory list (3:22472), likely replacing the add flow stack.
- What can I cook now?: navigate to Meals / recipe suggestions using current inventory.
- Storage count tiles: display only (could optionally deep-link to Inventory filtered by storage).
- Summary rows: display only, data from the just-saved items (name | qty unit · storage).
- Bottom nav: Inventory tab is selected.
