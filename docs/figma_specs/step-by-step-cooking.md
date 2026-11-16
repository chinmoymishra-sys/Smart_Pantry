# Step-by-step cooking (Figma node 3:23398)

**Journey label (Figma annotation, not app UI):** `23 · Cook / focused cooking mode`
(label chip: bg #f3f4f6, radius 10, padding 10/12, Inter Regular 12, uppercase, tracking 0.5, #111827)

Focused mode: **NO bottom navigation bar** on this screen. Only the iOS home indicator area at the bottom (h 26, centered bar 124x4, #111827, radius 100).

## Screen frame
- Mobile screen bg #f9fafb, min-height 874 (frame has 1px #e5e7eb border + radius 32 — device mock only).
- Status bar (annotation): h 48, padding-x 26, "9:41" Inter Regular 15 #111827; signal/wifi/battery icons right.

## Tree

### Header — column, padding top 10 / bottom 18 / x 22, gap 12
1. **Back navigation** (tap target) — row, h 44, min-w 64, gap 6, center aligned
   - Lucide `arrow-left` 20px, #111827
   - "Back" — Inter Regular 13, line-height normal, #111827
2. Title "Soften the tomatoes" — Inter Regular 28, line-height 1.15, tracking -0.8, #111827 (step title, dynamic)
3. Subtitle "Spinach chickpea skillet · Step 2 of 4" — Inter Regular 14, lh 1.45, #6b7280

### Content — column, padding top 6 / bottom 24 / x 22, gap 20, min-height 606
1. **Cooking progress** (column, gap 8)
   - **Step progress** — row of 4 equal segments (flex 1 each), gap 6, h 5, radius 100.
     - Completed segment: #111827; incomplete: #e5e7eb. Here: 1 filled, 3 grey.
   - "1 of 4 steps complete" — Inter Regular 12, lh 1.45, #6b7280
2. **Food photograph** — full width, h 170, radius 18, BoxFit.cover → `assets/images/spinach_chickpea_skillet_cooking.jpg`
3. Step primary instruction "Warm 15 ml olive oil in a frying pan over medium heat." — Inter **Medium** 20, lh 1.45, #111827
4. Step detail "Add 2 chopped tomatoes. Cook for about 6 minutes, stirring, until softened. Lower the heat if they catch." — Inter Regular 17, lh 1.45, #111827
5. **Timer card** — bg #f3f4f6 (muted card, transparent 1px border), radius 18, padding 16, column gap 12
   - Row, space-between, center:
     - Left column gap 3:
       - "04:32" — Inter **Semi Bold** 38, tracking -1, lh normal, #111827 (countdown mm:ss)
       - "remaining · 6-minute timer" — Inter Regular 12, #111827
     - **Pause timer** button — 48x48 circle, bg white (no border), centered Lucide `pause` 22px #111827. (When paused, swap to `play`.)
   - "Timer is a guide. Check the tomatoes as they cook." — Inter Regular 12, lh 1.45, #6b7280
   - **Restart timer** secondary button — full width, min-h 52, bg white, 1px #e5e7eb, radius 10, padding 14/16, row gap 10 centered: Lucide `rotate-ccw` 20px #111827 + "Restart timer" Inter Regular 15 #111827
6. **Ingredients & quantities** secondary button (same style as above): Lucide `list` 20px + "Ingredients & quantities"
7. **Mark step complete & next** primary button — full width, min-h 52, bg #111827, radius 10, padding 14/16, gap 10: Lucide `check` 20px white + "Mark step complete & next" Inter Regular 15 white
8. **Cooking navigation** — row, gap 10, two equal (flex 1) secondary buttons (min-h 52, white, 1px #e5e7eb, radius 10):
   - Lucide `arrow-left` 20px + "Previous"
   - "Exit & save progress" (no icon)

Note: large action buttons in the cooking flow use 15px Regular labels and min-height 52 (larger than the shared 13px Semi Bold primary button) — focused-mode button variant.

## Images
| Slot | Size | Radius | Asset |
|---|---|---|---|
| Food photograph (bowl of spinach chickpea tomato stew with spoon) | full width x 170 | 18 | `assets/images/spinach_chickpea_skillet_cooking.jpg` (1584x672 JPEG) |

## Interactive intent
- Countdown timer for the step (6-minute timer, showing 04:32 remaining). Pause button toggles pause/resume; "Restart timer" resets to 06:00.
- "Ingredients & quantities" opens the ingredients sheet/screen (see Cooking ingredients and exit, node 3:23451 — spec not captured due to Figma rate limit).
- "Mark step complete & next" fills the next progress segment and advances to step 3; on last step leads to Cooking completion.
- "Previous" goes to previous step (disable on step 1).
- "Exit & save progress" saves session → Resume cooking screen later.
- Back = same as exit with save.
