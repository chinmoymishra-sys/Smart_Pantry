# Cooking completion (Figma node 3:23572)

**Journey label (Figma annotation, not app UI):** `26 · Finish / check what happened`

Focused flow: **NO bottom navigation**; only home-indicator area (h 26, bar 124x4 #111827).

## Tree

### Header — column, padding top 10 / bottom 18 / x 22, gap 12
1. Back navigation — row h 44, gap 6: Lucide `arrow-left` 20 #111827 + "Back" Inter Regular 13 #111827
2. Title "How did it go?" — Inter Regular 28, lh 1.15, tracking -0.8, #111827
3. Subtitle "All 4 steps complete · 2 servings" — Inter Regular 14, lh 1.45, #6b7280

### Content — column, padding top 6 / bottom 24 / x 22, gap 20
1. **Food photograph** — full width x 260, radius 18, cover → `assets/images/spinach_chickpea_skillet_finished.jpg`
2. "Did you make the skillet?" — Inter Regular 20, lh 1.25, tracking -0.4, #111827
3. "We’ll help update your pantry with what you actually used. Nothing has been deducted yet." — Inter Regular 15, lh 1.45, #6b7280 (note curly apostrophe ’)
4. **Recipe summary card** (muted) — bg #f3f4f6, transparent 1px border, radius 18, padding 16, column gap 12, left aligned
   - Lucide `utensils` 28px #111827
   - "Spinach chickpea skillet" — Inter Regular 15, lh 1.45, #111827
   - "17 min estimated · Lunch · Prepared today" — Inter Regular 13, lh 1.45, #6b7280
5. **Primary button** — min-h 52, bg #111827, radius 10, padding 14/16, gap 10: Lucide `check` 20 white + "Yes · review ingredients used" Inter Regular 15 white
6. **Secondary button** "Not yet · save my progress" — min-h 52, white, 1px #e5e7eb, radius 10, Inter Regular 15 #111827
7. **Secondary button** "Skip inventory update" — same style
8. Footnote "Skipping leaves all quantities unchanged. You can record actual usage later from cooking history." — Inter Regular 12, lh 1.45, #6b7280

## Images
| Slot | Size | Radius | Asset |
|---|---|---|---|
| Food photograph (finished skillet bowl, fork, glass) | full width x 260 | 18 | `assets/images/spinach_chickpea_skillet_finished.jpg` (1200x896 JPEG) |

## Interactive intent
- Shown after the final step is marked complete.
- "Yes · review ingredients used" → Confirm ingredient deductions screen (node 3:23607).
- "Not yet · save my progress" → saves session (Resume cooking state).
- "Skip inventory update" → finishes cooking, logs to history with no deductions; quantities unchanged.
- No rating options exist on this screen.
