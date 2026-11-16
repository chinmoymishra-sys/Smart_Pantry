# Resume cooking (Figma node 3:23509)

**Journey label (Figma annotation, not app UI):** `25 · Cook / paused session`

Has the shared **bottom navigation**, with **Meals** selected.

## Tree

### Header — column, padding top 10 / bottom 18 / x 22, gap 12
1. Back navigation — row h 44, gap 6: Lucide `arrow-left` 20 #111827 + "Back" Inter Regular 13 #111827
2. Title "Pick up where you left off" — Inter Regular 28, lh 1.15, tracking -0.8, #111827
3. Subtitle "Cooking paused · your pantry is unchanged" — Inter Regular 14, lh 1.45, #6b7280

### Content — column, padding top 6 / bottom 24 / x 22, gap 20
1. **Food photograph** — full width x 226, radius 18, cover → `assets/images/spinach_chickpea_skillet_paused.jpg`
2. Recipe name "Spinach chickpea skillet" — section heading: Inter Regular 20, lh 1.25, tracking -0.4, #111827
3. **Cooking progress** (column gap 8)
   - 4 segments, gap 6, h 5, radius 100: 1st #111827, rest #e5e7eb
   - "1 of 4 steps complete" — Inter Regular 12, lh 1.45, #6b7280
4. **Session card** — white, 1px #e5e7eb, radius 18, padding 16, column gap 12
   - "Next: Step 2 · Soften the tomatoes" — Inter Regular 15, lh 1.45, #111827
   - "1 step completed · 2 servings" — Inter Regular 14, lh 1.45, #6b7280
   - **Detail row** (row gap 12): label column fixed width 140 "Timer paused at" Inter Regular 13 #6b7280 | value (flex) "04:32 remaining" Inter Regular 13 #111827
   - "The in-app timer is paused, but food can keep cooking. Check the pan before resuming." — Inter Regular 13, lh 1.45, #6b7280
5. **Resume step 2** primary button — full width, min-h 52, bg #111827, radius 10, padding 14/16, gap 10: Lucide `play` 20 white + "Resume step 2" Inter Regular 15 white
6. **View recipe from the beginning** secondary button — min-h 52, white, 1px #e5e7eb, radius 10; label Inter Regular 15 #111827 (no icon)
7. **Discard cooking progress…** destructive secondary button — same as secondary, label color **#b91c1c** (red-700), text ends with an ellipsis character "…"
8. **Guidance** info box — bg #f3f4f6, radius 10, padding 14, no border, row gap 10, top-aligned:
   - Lucide `info` 19px #111827
   - Column gap 4 (Inter Regular 13, lh 1.45):
     - "Inventory stays in your control" #111827
     - "Ingredient deductions are proposed only after cooking and need your confirmation." #6b7280

### Bottom navigation (shared)
White, top border 1px #e5e7eb, padding top 12 / bottom 8 / x 12, column gap 12 (destinations row + home indicator 124x4 #111827).
4 destinations in this frame (flex 1 each, gap 4, min-h 48, column gap 5): `house` "Overview", `scan-line` "Scan/Add", `refrigerator` "Inventory", `utensils` "Meals". Icons 22px. Unselected label Inter Regular 11 #6b7280 (icon #6b7280); selected = **Meals**: Inter Bold 11 #111827 (icon #111827).

## Images
| Slot | Size | Radius | Asset |
|---|---|---|---|
| Food photograph (skillet bowl, gold spoon, linen) | full width x 226 | 18 | `assets/images/spinach_chickpea_skillet_paused.jpg` (1264x848 JPEG) |

## Interactive intent
- Shown when a saved/paused cooking session exists (after "Exit & save progress").
- "Resume step N" → back to step-by-step screen at saved step with timer still paused at saved remaining time (04:32).
- "View recipe from the beginning" → recipe from step 1 (keep or reset progress — design implies read-only view).
- "Discard cooking progress…" → confirmation dialog (ellipsis implies a confirm step), then clears session; inventory untouched.
- No inventory changes happen while paused.
