# Smart Pantry

A local-first Flutter app for recording the food at home, tracking it by
storage location, finding meals that use what you already have, and
recording what was used after cooking. Everything is stored on the device in
SQLite. The app records only what the user enters and confirms; it never
infers quantities, dates, quality or safety.

## Stack
Flutter 3.47 / Dart 3.13 · Riverpod 3 · go_router · sqflite · camera ·
mobile_scanner · image_picker · Lucide icons · Inter (bundled)

## Run
```bash
flutter pub get
flutter run            # Android or iOS device/emulator
flutter analyze
flutter test           # unit, SQLite (sqflite_common_ffi) and widget tests
```
On Windows, enable Developer Mode before building, because plugins need
symlinks.

## Features
- **Overview:** item and storage counts, use-soon reminders based on your
  recorded dates, meal ideas, recent activity, and a first-use state.
- **Scan/Add:** camera (container / single item / groceries), photo upload,
  barcode/QR scanner with manual code entry, and manual entry with optional
  dates and condition. Every route ends in review (edit, confirm uncertain
  items, split, merge, remove) and an explicit **Confirm & save**, which
  writes everything in one transaction.
- **Inventory:** search, filters (storage, category, state, condition, date,
  stock), sorting, item details, and separate consume / set quantity / move /
  finish / discard / unavailable / remove actions, each recorded in history.
- **Meals:** recipe matching against confirmed stock, preference filters,
  recipe detail with a servings stepper, numbered instructions, and
  step-by-step cooking with a timer, pause/resume and exit. After cooking,
  you review and confirm the amounts used before anything is deducted.
- **History:** cooking, scans and inventory changes. Deleting a scan record
  keeps the items it added.
- Light and dark themes follow the system setting.

## Layout
```
lib/
  core/        theme tokens, shared widgets, navigation, enums, utils
  data/        SQLite database + migrations, recipe seed, repository impls
  features/    overview · capture · inventory · meals · cooking · history
               (models / controllers / repositories / views)
  providers/   dependency wiring
docs/          screen inventory, schema, design tokens, implementation notes
test/          core, features, data (SQLite) and widget tests
```

## Documentation
- `docs/FIGMA_SCREEN_INVENTORY.md`: design frames mapped to routes
- `docs/DATABASE_SCHEMA.md`: tables, transactions, migrations
- `docs/figma_specs/design-tokens.md`: verified light and dark tokens
- `docs/IMPLEMENTATION_NOTES.md`: capability limits, known deviations,
  content that needs review, next phase
- `docs/SCREEN_CONVENTIONS.md`: how screens are built

## Known limitations (Phase 1)
- No photo recognition service. Photos stay on the device and you add items
  yourself. The integration point is `RecognitionService`.
- No external product catalog. Barcode lookup only finds products your
  household confirmed before.
- No household sync.
- Three of the four seeded recipe methods are placeholders written for this
  build and need content review (see the implementation notes).
