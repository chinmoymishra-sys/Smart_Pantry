# Confirm inventory additions (Figma node 3:22045)

## 1. Journey label (Figma annotation, NOT app UI)
`06b · Review / ready to save` (rendered uppercase, 12px, tracking 0.5, bg #f3f4f6, radius 10, padding 10/12).

## 2. UI tree (top-down)

Font: Inter. Figma reports every text node as **Inter Regular (400)** on this screen — including the button labels. Use 400 unless the shared system overrides.

Screen: bg `#f9fafb`, mobile frame width 402 (device frame border/radius 32 are mock chrome). Status bar (h48, "9:41") and home indicator (124x4, `#111827`, radius 100, in a 26px-high area) are device chrome.

### Header — padding top 10, bottom 18, horizontal 22; column, gap 12
- **Back navigation** (button, h44, min-w 64, row gap 6, centered vertically)
  - Lucide `arrow-left` 20px, `#111827`
  - Text `Back` — 13px, line-height normal, `#111827`
- **Title** `Ready for your pantry` — 28px, line-height 1.15, tracking -0.8, `#111827`
- **Subtitle** `3 of 3 selected items confirmed` — 14px, line-height 1.45, `#6b7280`

### Content — padding top 6, bottom 24, horizontal 22; column, gap 20 (min-h 606)
1. **Food photograph** — full width x **176** high, radius 18, `BoxFit.cover`. Asset `assets/images/spinach_tomatoes_peas.png`.
2. **Guidance banner** (info callout) — bg `#f3f4f6`, NO border, radius 10, padding 14, row gap 10, crossAxis start
   - Lucide `info` 19px, `#111827`
   - Column gap 4, 13px, line-height 1.45:
     - `Reviewed by you` — `#111827`
     - `You confirmed the names, quantities and storage below. Quality and safety remain not assessed.` — `#6b7280`
3. **Confirmed items card** — standard card (white, 1px `#e5e7eb`, radius 18, padding 16), column gap 12. Three rows, each: row gap 10, crossAxis start
   - Lucide `circle-check` 22px, `#111827` (outline, not filled)
   - Column gap 5, line-height 1.45:
     - Title 15px `#111827`; meta 13px `#6b7280`
   - Rows (verbatim):
     - `Spinach · 150 g` / `Raw · Fridge · Use by 8 Nov (your date)`
     - `Tomatoes · 4 pieces` / `Raw · Fridge · Use by 11 Nov (your date)`
     - `Green peas · 300 g` / `Frozen · Freezer · Expiry not set`
4. **Summary card (muted)** — bg `#f3f4f6`, 1px transparent border, radius 18, padding 16, column gap 12. Detail rows: row gap 12; label column fixed **140** wide (13px, lh 1.45, `#6b7280`), value Expanded (13px, lh 1.45, `#111827`, wraps):
   - `Before saving` → `9 unique items`
   - `After saving` → `12 unique items`
   - `Storage totals` → `Fridge 6 · Freezer 2 · Pantry 4`
5. **Primary action button** — full width, min-h 52, padding 14 v / 16 h, bg `#111827`, radius 10, row centered gap 10
   - Lucide `check` 20px, white
   - `Confirm & save 3 items` — 15px, white, line-height normal
6. **Secondary action button** (outlined) — full width, min-h 52, padding 14/16, bg white, 1px `#e5e7eb`, radius 10
   - `Go back and edit selections` — 15px `#111827`
7. **Footnote** `Save is the only action here that adds these items to inventory.` — 12px, lh 1.45, `#6b7280`

No bottom navigation bar on this screen (it's a flow step; only home indicator below content).

## 3. Images
| Slot | Size | Radius | Asset |
|---|---|---|---|
| Hero food photo (spinach bunch, vine tomatoes, bag of frozen peas on stone counter) | full width x 176 | 18 | `assets/images/spinach_tomatoes_peas.png` (actually JPEG data, 1376x768; Flutter decodes by content) |

## 4. Interactive intent
- **Back** — pop to previous review step (detection/review list).
- **Confirm & save 3 items** — commit the 3 confirmed items to inventory, then navigate to inventory/overview with success feedback. Count in label is dynamic.
- **Go back and edit selections** — pop back to the editable review list without saving.
- Item rows are read-only here; summary values (before/after counts, storage totals) are computed.
