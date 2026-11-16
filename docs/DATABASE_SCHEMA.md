# Database schema

SQLite via `sqflite`, file `smart_pantry.db`, schema version **1**
(`lib/data/database/app_database.dart`). Migrations are an ordered
`version → function` map; shipped migrations are never edited and the
database is never deleted on startup. Foreign keys are enabled
(`PRAGMA foreign_keys = ON`). Timestamps are UTC ISO-8601; calendar dates
are `yyyy-MM-dd`; booleans are `0/1`. Unknown dates are `NULL`.

| Table | Purpose |
|---|---|
| `pantry_items` | Confirmed inventory records only. Quantity + explicit unit, storage, food state, user-recorded condition/freshness (default `not_assessed`), optional dates, low-stock threshold, package content (e.g. 240 g drained per tin), photo path, source, `is_unavailable`. `CHECK (quantity >= 0)`. |
| `pantry_item_photos` | App-managed photo file paths per item (cascade on item delete). |
| `inventory_transactions` | Immutable history: `item_added`, `quantity_consumed`, `quantity_set`, `moved`, `marked_finished`, `discarded`, `marked_unavailable`, `marked_available`, `item_removed`, `item_edited`, `cooking_deduction`. Keeps an item-name snapshot so history survives removal. |
| `capture_drafts` | One open capture draft (method, mode, source photo, barcode, status). |
| `detection_drafts` | Reviewable items of a draft. Keeps `quantity_source` (`user_entered` / `user_measured` / `visual_estimate`), `is_identity_confirmed`, `is_selected`, dates, merge target. Never counted as inventory. |
| `barcode_products` | Local household catalog, written only from the user's own confirmed barcode entries. No external/fabricated data. |
| `scan_history` | Saved capture records (photo, item names, count). Deleting one never deletes inventory. |
| `recipes`, `recipe_ingredients`, `recipe_steps` | Local recipe catalog seeded on create (`recipe_seed.dart`). Ingredients carry `match_keys` and `is_required`. |
| `meal_preferences` | Single `default` row of meal discovery preferences. |
| `cooking_sessions` | Step progress, timer remaining, status (`active`, `paused`, `awaiting_review`, `completed`, `completed_without_update`, `abandoned`), feedback, favourite flag. |
| `cooking_usage` | Confirmed per-ingredient usage with before/after balances; skipped rows recorded but not deducted. |

## Transaction boundaries
- **Confirm & save** (`SqliteCaptureRepository.commitDraft`): all pantry inserts / reviewed merges, `item_added` transactions, barcode catalog upserts, the scan record and draft status — one transaction; any failure rolls back everything.
- **Cooking deductions** (`SqliteCookingRepository.confirmDeductions`): balances re-validated inside the transaction; updates, `cooking_deduction` transactions, usage rows and session completion are atomic.
- Every lifecycle action (consume, set, move, finish, discard, unavailable, remove, edit) writes its item change and history row in one transaction.
- Session/draft rows are upserted with `UPDATE … / INSERT`, never `INSERT OR REPLACE`, because a REPLACE would cascade-delete child rows.

Tests: `test/data/database_test.dart` (in-memory and file-backed via `sqflite_common_ffi`).
