# What can I cook (Figma 3:23057)

## 1. Journey label (Figma annotation, NOT app UI)
`19 · Discover / 12-item pantry`

## 2. UI tree
All text is Inter Regular (400) unless stated. Screen bg is #f9fafb. This is a top-level tab (Meals), so there is no back button.

### Header (padding: top 10, bottom 18, horizontal 22; gap 12)
- Title "What can I cook?": 28/1.15, tracking -0.8, #111827
- Subtitle "Good food starts with what’s already here." (curly apostrophe): 14/1.45 #6b7280

### Content (padding: top 6, bottom 24, horizontal 22; column gap 20; scrolls)
1. **Action row** (row, gap 10; two equal flex-1 buttons). Each button: white, 1px #e5e7eb, radius 10, min height 52, padding 14×16, gap 10, centered.
   - Lucide `sliders-horizontal` 20 #111827 + "Filters" 15 #111827. Opens Meal filters (3:23164).
   - Lucide `leaf` 20 #111827 + "Use soon first" 15 #111827. Sort toggle that prioritises recipes using items expiring soon. Only the unselected-looking style is shown.
2. **Meal-type chips** (wrap, gap 8; single-select). Chip styles are the same as the shared filter chip:
   - Selected: bg #111827, border #111827, radius 100, min height 44, padding 11×14, gap 6, Lucide `check` 14 white, label 13 white.
   - Unselected: white, 1px #e5e7eb, label 13 #111827.
   - Chips: **"All meals" (selected)**, "Breakfast", "Lunch", "Snacks", "Dinner".
3. **Guidance banner**: bg #f3f4f6, radius 10, padding 14, row gap 10, items aligned to top.
   - Lucide `info` 19px #111827 (text colour)
   - Message column (gap 4, 13/1.45):
     - "Make the most of your spinach" #111827
     - "Your recorded use-by date is 8 Nov. The lunch skillet uses 100 g of your 150 g." #6b7280
4. **Meal suggestion cards** ×4. Each card: white, 1px #e5e7eb, radius 18, clip, column, no outer padding.
   - Food photo: full width × **172 height**, radius 18 (all corners), cover.
   - Recipe information (padding 16, column gap 10):
     - Meal type label in uppercase: 11/1.45 #111827 (e.g. "BREAKFAST")
     - Name: 20/1.25, tracking -0.4, #111827
     - Description: 14/1.45 #6b7280
     - Meta line "{prep} min prep · {cook} min cook · {difficulty} · Serves {n}": 12/1.45 #6b7280
     - Availability "{x} of {y} required ingredients available": 13/1.45. Colour is #111827 when all are available and **#b45309 (amber)** when some are missing.
     - "Available / planned use: …": 13/1.45 #111827
     - Either "Optional: … · not in inventory" (12/1.45 #6b7280) or "Need to buy: …" (13/1.45 **#b45309**)
     - Recipe link row: height 44, space-between. "View recipe" 14/normal #111827 + Lucide `arrow-up-right` 19 #111827. Tap opens Recipe detail.

   Card data (verbatim):
   | # | Type | Name | Description | Meta | Availability | Available line | Last line | Photo |
   |---|---|---|---|---|---|---|---|---|
   | 1 | BREAKFAST | Berry & yogurt oats | A warm bowl with a cool, creamy finish. | 3 min prep · 5 min cook · Easy · Serves 1 | 3 of 3 required ingredients available (#111827) | Available / planned use: Oats 50 g · Blueberries 50 g · Yogurt 100 g | Optional: Honey · not in inventory | berry_yogurt_oats.jpg |
   | 2 | LUNCH | Spinach chickpea skillet | Tender greens, tomatoes and golden chickpeas. | 5 min prep · 12 min cook · Easy · Serves 2 | 4 of 4 required ingredients available (#111827) | Available / planned use: Spinach 100 g · Tomatoes 2 · Chickpeas 1 tin · Olive oil 15 ml | Optional: ½ lemon · not in inventory | spinach_chickpea_skillet.jpg |
   | 3 | SNACKS | Paneer tomato toast | A crisp, savory afternoon pick-me-up. | 5 min prep · 5 min cook · Easy · Serves 2 | 2 of 3 required ingredients available (#b45309) | Available / planned use: Paneer 100 g · Tomato 1 | Need to buy: Bread · 2 slices (#b45309) | paneer_tomato_toast.jpg |
   | 4 | DINNER | Peas & onion rice | A simple one-pot dinner for a quiet evening. | 5 min prep · 20 min cook · Easy · Serves 2 | 3 of 4 required ingredients available (#b45309) | Available / planned use: Rice 150 g · Green peas 100 g · Olive oil 10 ml | Need to buy: Onion · 1 piece (#b45309) | peas_onion_rice.jpg |

   Ordering in the design: fully-available recipes come first, then partially-available ones. Within each group they're in meal order.
5. Footnote "Matches use confirmed quantities, not photos. Suggestions reflect selected preferences, not allergy guarantees. Photos are illustrative." 12/1.45 #6b7280.

### Bottom navigation (shared)
White, top border 1px #e5e7eb, padding top 12, bottom 8, horizontal 12. Destinations row with gap 4, each item flex-1, column gap 5, min height 48, centered.
- **This frame shows 4 destinations**: `house` "Overview", `scan-line` "Scan/Add", `refrigerator` "Inventory", `utensils` "Meals".
- Icons are 22px. Labels are 11/normal.
- Inactive: icon and label #6b7280, Regular.
- Active (**Meals**): icon and label #111827, label **Inter Bold 700**.
- The 124×4 home indicator under the row is a mockup artefact.

## 3. Images
| Slot | Size | Radius | Fit | Asset |
|---|---|---|---|---|
| Card 1 photo: oat bowl with blueberries and yogurt | full width × 172 | 18 | cover | `assets/images/berry_yogurt_oats.jpg` |
| Card 2 photo: skillet of spinach, tomato and chickpeas | full width × 172 | 18 | cover | `assets/images/spinach_chickpea_skillet.jpg` |
| Card 3 photo: toast topped with paneer and tomato | full width × 172 | 18 | cover | `assets/images/paneer_tomato_toast.jpg` |
| Card 4 photo: bowl of peas and onion rice | full width × 172 | 18 | cover | `assets/images/peas_onion_rice.jpg` |

All four source photos are 1584×672 JPEGs.

## 4. Interactive intent
- The meal-type chips filter the list (single-select, with "All meals" as the default).
- "Filters" opens the Meal filters screen.
- "Use soon first" toggles sorting by soonest-expiring pantry items. The banner highlights the most urgent item (spinach, use-by 8 Nov) and which recipe uses it.
- The whole card and/or "View recipe" opens Recipe detail.
- Availability is computed from the confirmed inventory quantities against the recipe's required ingredients. Missing required items switch the colour to amber and show a "Need to buy" line. Optional ingredients that aren't in inventory are listed muted.
