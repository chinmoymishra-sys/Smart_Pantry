# Dates, condition and notes (Figma 3:22988)

## 1. Journey label (Figma annotation, NOT app UI)
`18 · Edit continuation / all inventory fields`

## 2. UI tree
All text is Inter Regular (400) unless stated. Screen bg is #f9fafb, with no bottom nav (pushed screen).

### Header (padding: top 10, bottom 18, horizontal 22; gap 12)
- Back row: height 44, gap 6. Lucide `arrow-left` 20 #111827, then "Back" 13 #111827.
- Title "The details that matter": 28/1.15, tracking -0.8, #111827.
- Subtitle "Spinach · editable review or inventory details": 14/1.45 #6b7280.

### Content (padding: top 6, bottom 24, horizontal 22; column gap 20)
**Editable field pattern:** a column with gap 7.
- Label: Inter Semi Bold 600, 13/1.45, #111827.
- Input box: white, 1px #e5e7eb, radius 10, min height 50, padding 14. Value 15/1.45 #111827.
- Optional helper text below the input: 12/1.45 #6b7280.

Dropdown fields show their value followed by a chevron. In Figma the chevron is the literal text "⌄" after 5 spaces. Implement it as a dropdown or select with a trailing chevron (Lucide `chevron-down` ~16 #6b7280 is suggested).

Fields in order:
1. "Date added": "6 Nov 2026" (date picker)
2. "Purchase date (optional)": "6 Nov 2026" (date picker)
3. "Date type": "Use by" (dropdown; implied options are Use by / Best before)
4. "Expiry / best-before (optional)": "8 Nov 2026" (date picker). Helper: "Source: entered by you. Leave blank if unknown."
5. "Opened / prepared date (optional)": "Not set" (date picker; the placeholder value is shown in #111827)
6. "Quality / condition": "Not assessed" (dropdown)
7. "Freshness": "Not assessed" (dropdown)
8. Standalone note: "You can record fresh, good, use soon or spoiled / unsafe after your own assessment. The app cannot assess safety from a photo." 12/1.45 #6b7280. This implies the Freshness options are Not assessed / Fresh / Good / Use soon / Spoiled / unsafe.
9. "Notes": multi-line input with **min height 82**, value "Washed weight. For lunch this week."
10. **Item photo row**: row, gap 14, centered vertically.
    - Thumbnail: width 90, height 80, radius 18, image cover-fit (`assets/images/spinach_bowl.jpg`).
    - Photo controls column (flex 1, gap 8): two secondary buttons (white, 1px #e5e7eb, radius 10, min height 52, padding 14×16, centered):
      - "Replace photo": 15 #111827
      - "Delete photo": 15 **#b91c1c**
11. "Low-stock alert (optional)": value "Off · set a threshold in g" (numeric input; the unit follows the item's unit)
12. **Primary button** "Save details & return to review": full width, bg #111827, radius 10, min height 52, label 15 white.
13. Footnote "In a new-item flow, saving these details returns to confirmation; it does not silently add inventory." 12/1.45 #6b7280.

### Home area
26px with a home indicator. Mockup only.

## 3. Images
| Slot | Size | Radius | Fit | Asset |
|---|---|---|---|---|
| Item photo thumbnail (bowl of fresh spinach leaves) | 90×80 | 18 | cover | `assets/images/spinach_bowl.jpg` (source 1024×1024 JPEG) |

At runtime this should be the item's own user photo. The asset is a demo/seed image.

## 4. Interactive intent
- All fields are editable. Dates open a date picker, and "optional" fields can be cleared back to "Not set".
- Replace photo opens the camera or gallery. Delete photo removes it (red, destructive; consider a confirmation).
- Save writes the details. In the add-item flow it returns to the review/confirmation screen and doesn't commit to inventory. In the edit flow it pops back.
