# Finish, discard or remove (Figma 3:22939)

## 1. Journey label (Figma annotation, NOT app UI)
`17 · Track / item lifecycle` (rendered uppercase in Figma: 12px, tracking 0.5, bg #f3f4f6, radius 10).

## 2. UI tree
All text is Inter Regular (400) unless stated. Font size / line-height are given as `size/lh` (lh is a multiplier; "normal" means the font default).

Screen: bg #f9fafb, no bottom nav (it's a pushed detail screen). The status bar (48px tall, "9:41") is part of the mockup only.

### Header (padding: top 10, bottom 18, horizontal 22; column gap 12)
- **Back navigation** row: height 44, min width 64, gap 6. Lucide `arrow-left` 20px #111827, then "Back" 13/normal #111827. Tap pops the screen.
- Title "What happened to it?": 28/1.15, tracking -0.8, #111827.
- Subtitle "Spinach · 150 g · choose an action": 14/1.45, #6b7280.

### Content (padding: top 6, bottom 24, horizontal 22; column gap 20)
1. **Card "Mark as finished"** (standard card: white, 1px #e5e7eb border, radius 18, padding 16, column gap 12)
   - "Mark as finished": 15/1.45 #111827
   - "Set balance to zero and keep its usage history.": 13/1.45 #6b7280
   - **Secondary button**, full width: white bg, 1px #e5e7eb border, radius 10, min height 52, padding 14×16, centered. Label "Finished · used it all" 15/normal #111827.
2. **Card "Discard or mark unavailable"** (standard card, gap 12)
   - "Discard or mark unavailable": 15/1.45 #111827
   - "Discard records waste. Unavailable excludes the item from meal suggestions without deleting it.": 13/1.45 #6b7280
   - **Single-select chip group** (wrap, gap 8):
     - Selected chip "Discard": bg #111827, 1px border #111827, radius 100 (pill), min height 44, padding 11×14, gap 6. Lucide `check` 14px white, then the label 13/normal white.
     - Unselected chip "Unavailable": bg white, 1px #e5e7eb border, same size, no icon, label 13 #111827.
3. **Confirmation panel (danger)**: bg **#fef2f2**, transparent border, radius 18, padding 16, column gap 12
   - "Discard all 150 g?": section heading 20/1.25, tracking -0.4, #111827
   - **Text field** (column gap 7):
     - Label "Reason (optional)": Inter **Semi Bold 600**, 13/1.45, #111827
     - Input: white, 1px #e5e7eb, radius 10, min height 50, padding 14. Value "No longer usable · assessed by me" 15/1.45 #111827.
   - Warning "This sets the remaining amount to 0 g. Only confirm after checking the item yourself.": 13/1.45, **#b91c1c**.
   - **Primary button** "Confirm discard": full width, bg #111827, radius 10, min height 52, padding 14×16. Label 15/normal white (Regular weight here, not Semi Bold).
   - **Secondary button** "Keep item": white, 1px #e5e7eb, radius 10, min height 52. Label 15 #111827.
4. **Destructive outline button**: white, 1px #e5e7eb, radius 10, min height 52, padding 14×16, gap 10, centered. Lucide `trash-2` 20px (red #b91c1c), then the label "Remove item and its photo…" (with an ellipsis character) 15/normal **#b91c1c**.
5. Footnote "Remove asks for a separate final confirmation and deletes the item record, not just its remaining quantity.": 12/1.45 #6b7280.

### Home area
Height 26, centered home indicator 124×4, #111827, radius 100. This is an iOS mockup artefact, so don't render it.

## 3. Images
None.

## 4. Interactive intent
- "Finished · used it all": sets the remaining quantity to 0, keeps the usage history and marks the item finished.
- Discard/Unavailable chips are a single-select toggle. The danger panel below reflects the selected mode. With "Discard" selected it shows "Discard all {qty}?", an optional reason field (prefilled suggestion), "Confirm discard" (sets the remaining amount to 0 and logs waste with the reason) and "Keep item" (cancels and pops back). If "Unavailable" is selected, the item is excluded from meal suggestions and not deleted. The copy for that variant is not shown in the design.
- "Remove item and its photo…" opens a separate final confirmation dialog. It deletes the item record and the photo.
