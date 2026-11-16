# Figma screen inventory

Source: Figma file `AMGzJXAI9GRu4FA0ue5NiM` (34 frames × light/dark) and its
PDF export. Verbatim copy and positions per frame are in
`docs/figma_specs/screen_text/`. "Route" is the app route implementing it.

| # | Frame | Route / widget | Nav bar |
|---|---|---|---|
| 01 | Overview | `/` `OverviewScreen` | ✓ |
| 02 | Scan & add | `/scan` `ScanAddScreen` | ✓ |
| 03 | Camera capture | `/capture/camera` `CameraCaptureScreen` | – |
| 04 | Selected photo | `/capture/photo` `SelectedPhotoScreen` | – |
| 05 | Review detected items | `/capture/review` `ReviewScreen` | – |
| 06 | Edit detection | `/capture/review/edit/:id`, `/capture/review/new` `EditDetectionScreen` | – |
| 06b | Confirm inventory additions | `/capture/confirm` `ConfirmAdditionsScreen` | – |
| 07 | Barcode and QR scanner | `/capture/barcode` `BarcodeScannerScreen` | – |
| 08 | Barcode product result | `/capture/barcode/result` `BarcodeResultScreen` | – |
| 09 | Manual add | `/capture/manual` `ManualAddScreen` | – |
| 09b | Manual add details | `/capture/manual/details` `ManualDetailsScreen` | – |
| 10 | Split and merge detections | `/capture/split-merge` `SplitMergeScreen` | – |
| 11 | Inventory saved | `/scan/saved` `InventorySavedScreen` | ✓ |
| 12 | Inventory list | `/inventory` `InventoryListScreen` | ✓ |
| 13 | Inventory filters and sort | `/inventory/filters` `InventoryFiltersScreen` | – |
| 14 | Inventory item detail | `/inventory/item/:id` `ItemDetailScreen` | – |
| 15 | Quantity controls | `/inventory/item/:id/quantity` `QuantityScreen` | – |
| 16 | Move inventory item | `/inventory/item/:id/move` `MoveItemScreen` | – |
| 17 | Finish, discard or remove | `/inventory/item/:id/lifecycle` `LifecycleScreen` | – |
| 18 | Dates, condition and notes | `/inventory/item/:id/edit` `EditItemScreen` | – |
| 19 | What can I cook | `/meals` `MealsScreen` | ✓ |
| 20 | Meal filters | `/meals/filters` `MealFiltersScreen` | – |
| 21 | Recipe detail | `/meals/recipe/:id` `RecipeDetailScreen` | – |
| 22 | Recipe instructions | `/meals/recipe/:id/instructions` `RecipeInstructionsScreen` | – |
| 23 | Step-by-step cooking | `/cook` `CookingStepScreen` | – |
| 24 | Cooking ingredients and exit | `/cook/ingredients` `CookingIngredientsScreen` | – |
| 25 | Resume cooking | `/meals/resume` `ResumeCookingScreen` | ✓ |
| 26 | Cooking completion | `/cook/complete` `CookingCompleteScreen` | – |
| 27 | Confirm ingredient deductions | `/cook/deductions` `DeductionsScreen` | – |
| 28 | Cooking success and history | `/meals/cooked/:id` `CookingDoneScreen` | ✓ |
| 29 | Activity and scan history | `/history` `HistoryScreen` | ✓ |
| 30 | State library: starting & finding | first-use (Overview, Inventory), meals no-match (Meals), unknown barcode (Barcode result), required ingredient missing (Recipe detail), remove confirmation (Lifecycle) | |
| 31 | State library: capture & permissions | `/capture/permission/:kind`, recognition states (`/capture/recognition`), uncertain detections (Review) | |
| 32 | State library: waiting & control | recognition loading; meals loading. **Offline / sync failed / conflicting edit are not implemented** — Phase 1 is local-only with no household sync (see IMPLEMENTATION_NOTES). | |

Dark theme frames map 1:1 to the same widgets via `AppColors.dark`
(`ThemeMode.system`).
