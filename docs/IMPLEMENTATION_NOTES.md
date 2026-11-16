# Implementation notes

## How the design was sourced
- Figma file `AMGzJXAI9GRu4FA0ue5NiM`, page 1: 34 screen frames in both light
  and dark themes. The Figma MCP reached its Starter-plan call limit after a
  few frames, so most specs came from the matching PDF export (`Untitled.pdf`):
  - text with positions and sizes per frame → `docs/figma_specs/screen_text/`
  - vector fills of both pages → colour tokens (`figma_specs/design-tokens.md`)
  - embedded photos → `assets/images/`
  - per-frame renders were used as the visual target while building screens.
- The grey "journey label" chips above each frame ("05 · Review / before
  saving") and the iOS status bar are Figma annotations, not app UI.
- Icons are the Lucide set used in the design (`lucide_icons_flutter`). Inter
  is bundled locally so the app looks right offline.

## Architecture
MVC + Riverpod 3. Views (`features/*/views`) only watch providers and call
controller methods. Controllers (`features/*/controllers`) are
`Notifier`/`AsyncNotifier`s that talk to repository interfaces
(`features/*/repositories`). SQLite implementations live in
`lib/data/repositories` and own all SQL. Derived values (storage counts,
use-soon, low stock, recipe availability, activity feed) are computed from
persisted records and never stored twice.

## Honest capability boundaries (Phase 1, local-only)
- **Photo recognition:** there is no recognition service. `RecognitionService`
  (`features/capture/services`) is a swappable boundary whose current
  implementation always reports *unavailable*. Tapping "Identify food" shows
  that state, keeps the photo on the device, and routes to review, where the
  user adds items by hand. No detections are ever invented.
  `CaptureController.addSuggestedDetections` is ready for a real service: its
  suggestions arrive unconfirmed, with visual-estimate quantities.
- **Barcode lookup:** there is no external product catalog. Scanning works (via
  `mobile_scanner`), and the lookup checks a *local* table that is filled only
  from barcodes the household confirmed before. Unknown codes show the
  design's unknown-product state; no brand, nutrition or size is filled in.
- **Household sync:** not implemented. The design's offline / sync-failed /
  conflicting-edit states are reference states for a future connected phase.
  All data is on the device, so there is nothing to show as "offline".

## Product rules enforced in code
- Drafts never change inventory. `commitDraft` is the only path from capture
  to the pantry. It runs in a single transaction and refuses unresolved
  identities or missing quantities.
- Quantity and unit are always stored together. Only compatible units are
  converted (g↔kg, ml↔L), and count units never become weights.
- Unknown dates stay `NULL`. Quality and freshness default to `not_assessed`.
- Consume, set quantity, move, finish, discard, unavailable and remove are
  separate repository methods, each writing its own history entry. Move never
  changes food state or expiry. Remove deletes the record and its
  app-managed photo.
- Starting, pausing, exiting or finishing cooking never changes inventory.
  Deductions are proposed, editable and skippable, and are applied only by
  `confirmDeductions`. That method re-checks live balances inside one
  transaction and refuses over-deduction; nothing is ever silently clamped.
- Meal matching (`RecipeMatcher`) uses confirmed, usable stock only. Only
  required ingredients decide availability. Insufficient stock and unit
  mismatches are reported, never guessed. Dietary filters are preferences;
  the UI says they are not allergy guarantees.

## Content needing review
- The seeded recipe catalog is in `lib/data/database/recipe_seed.dart`.
  *Spinach chickpea skillet* is transcribed from the design: ingredients,
  equipment and all four steps. The design shows only card-level data (name,
  times, servings, ingredients) for *Berry & yogurt oats*, *Paneer tomato
  toast* and *Peas & onion rice*. Their methods, equipment, cuisine and diet
  tags were written to fit that data and **should be approved by a content
  owner**.
- The design has dedicated stage photos only for the skillet (detail,
  instructions, cooking, paused, finished, success) and the paneer
  "missing ingredient" state. Other recipes reuse their card photo
  (`RecipeImages` in `meal_widgets.dart`).

## Notable deviations from the frames
- Bottom navigation has four destinations (Overview, Scan/Add, Inventory,
  Meals), as in the frames. History opens from Overview.
- Manual add offers all supported unit chips, including tins and slices: the
  design's sample data uses "2 tins" and "2 slices".
- Feedback chips on the cooking-success screen are single-select; the frame
  shows two selected.
- The quantity screen in "Set quantity" mode is titled "How much is there
  now?" because the design shows only the Consume variant.
- Recognition copy is adapted to say that recognition is unavailable in this
  build, rather than "isn't responding".

## Platform notes
- Android: `CAMERA` permission added. `permission_handler` is pinned to 12.x because 13.x requires compileSdk 37 (beyond AGP 9.1). minSdk is Flutter's default of 24,
  which `permission_handler`, `camera` and `mobile_scanner` accept.
- iOS: `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` added.
  To limit `permission_handler` to the permissions actually used, add the
  `PERMISSION_CAMERA=1` / `PERMISSION_PHOTOS=1` macros in `ios/Podfile`
  (see the permission_handler README). This needs a macOS build machine and
  hasn't been verified here.
- On Windows, building with plugins requires Developer Mode (symlink
  support).

## Future backend phase
Add remote data sources behind the existing repository interfaces. Introduce
a sync queue table and the design's sync / conflict states. Swap in a real
`RecognitionService` and a product-catalog lookup with explicit user consent
before anything is uploaded.
