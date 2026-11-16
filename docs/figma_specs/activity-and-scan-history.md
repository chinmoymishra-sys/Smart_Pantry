# Activity and scan history (light) — Figma node 3:23766

Journey label (Figma annotation, NOT app UI): `29 · History / household record`
(label chip: bg #f3f4f6, radius 10, padding 10/12, Inter Regular 12, uppercase, tracking 0.5, #111827)

Status bar (annotation/system): "9:41" Inter Regular 15 #111827, height 48, padding-x 26; signal/wifi/battery icons.

## Screen container
- Mobile frame: bg #f9fafb, 1px border #e5e7eb, radius 32 (frame only), min-height 874.
- Column layout: Header → Content (scrolls) → Primary navigation (bottom).

## Header (padding top 10, bottom 18, horizontal 22, gap 12)
1. Back navigation row: height 44, min-width 64, gap 6, center aligned.
   - Lucide `arrow-left` 20px, #111827
   - "Back" Inter Regular 13, #111827
   - Intent: pops route.
2. Title "A little more organized" — Inter Regular 28, line-height 1.15, tracking -0.8, #111827.
3. Subtitle "Friday, 6 November · Activity" — Inter Regular 14, line-height 1.45, #6b7280. (Date is dynamic.)

## Content (padding top 6, bottom 24, horizontal 22, gap 20, min-height 606)

### 1. Filter chips (Wrap, spacing 8, runSpacing 8) — single-select
- Selected chip "All activity": bg #111827, 1px border #111827, radius 100 (pill), min-height 44, padding 11v/14h, gap 6; Lucide `check` 14px white; text Inter Regular 13 white.
- Unselected chips "Food added", "Cooking", "Scans": bg #ffffff, 1px border #e5e7eb, radius 100, min-height 44, padding 11/14; text Inter Regular 13 #111827; no icon.
- Intent: filters the activity list below.

### 2. Card — cooking activity
Card: bg white, 1px #e5e7eb, radius 18, padding 16.
Row (gap 12, crossAxis start):
- Lucide `utensils` 22px #111827
- Column (expanded, gap 4):
  - "Cooked spinach chickpea skillet" — Inter Semi Bold 15, lh 1.45, #111827
  - "12:45 · 2 servings · deductions confirmed" — Inter Regular 13, lh 1.45, #6b7280
  - Two lines, Inter Regular 13, lh 1.45, #111827:
    - "Spinach −100 g · Tomatoes −2 pieces"
    - "Chickpeas −1 tin · Olive oil −15 ml"
    (uses U+2212 minus sign)

### 3. Card — scan record (column, gap 12, padding 16, radius 18, border #e5e7eb, bg white)
- "3 items added after review" — Inter Semi Bold 15, lh 1.45, #111827
- "10:04 · Spinach, tomatoes and green peas" — Inter Regular 13, lh 1.45, #6b7280
- Image: full width, height 142, radius 18, BoxFit.cover → `assets/images/scan_spinach_tomatoes_peas.jpg` (1584x672 JPEG; overhead photo of spinach, tomatoes, bag of peas on wooden board). In app this is the user's saved scan photo (dynamic); asset is placeholder.
- Secondary button "Review saved scan record": full width, min-height 52, bg white, 1px #e5e7eb, radius 10, padding 14v/16h, centered text Inter Regular 15 #111827. Intent: open saved scan record.
- Destructive secondary button "Delete scan photo & record…": same style as above but text color #b91c1c (error red). Ends with ellipsis "…" (U+2026). Intent: opens confirmation dialog before deleting.

### 4. Card — simple added items (column, gap 12, padding 16, radius 18, border #e5e7eb, bg white, all lh 1.45)
- "Plain yogurt added" — Semi Bold 15 #111827
- "8:20 · 400 g · Fridge" — Regular 13 #6b7280
- "Milk added" — Semi Bold 15 #111827
- "8:18 · 1 L · Fridge" — Regular 13 #6b7280
(Note: no divider between entries; just gap 12.)

### 5. Guidance / info callout
- Container: bg #f3f4f6, radius 10, padding 14, no border; Row gap 10, crossAxis start.
- Lucide `info` 19px #111827 (dark grey/neutral)
- Column (gap 4), Inter Regular 13, lh 1.45:
  - "Your record, your choice" — #111827
  - "Deleting a scan record asks for confirmation. Confirmed inventory items remain unless you remove them separately." — #6b7280

## Primary navigation (bottom bar)
- Container: bg white, top border 1px #e5e7eb, padding top 12, bottom 8, horizontal 12, column gap 12, center.
- Destinations row: 4 equal Expanded items, gap 4; each column gap 5, min-height 48, centered.
  - Active "Overview": Lucide `house` 22px #111827; label Inter Bold 11 #111827.
    (Note: in this frame Overview is shown active even though this is the History screen — History is reached from Overview.)
  - "Scan/Add": Lucide `scan-line` 22px #6b7280; label Inter Regular 11 #6b7280
  - "Inventory": Lucide `refrigerator` 22px #6b7280; label Regular 11 #6b7280
  - "Meals": Lucide `utensils` 22px #6b7280; label Regular 11 #6b7280
- Home indicator: 124x4, radius 100, #111827 (iOS system — draw only if mimicking; normally omit).

## Semantic colors used
- Error/destructive text: #b91c1c
- Info callout bg: #f3f4f6 (neutral)
