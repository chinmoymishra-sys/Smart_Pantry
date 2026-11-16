import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'recipe_seed.dart';

/// Versioned SQLite database. Never deleted on startup; schema changes go
/// through [_migrations].
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const fileName = 'smart_pantry.db';
  static const schemaVersion = 1;

  /// Opens (creating/migrating as needed). [factory] and [path] allow tests
  /// to use sqflite_common_ffi with an in-memory database.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final resolved = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      resolved,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _migrateBetween(db, 0, version);
        },
        onUpgrade: (db, from, to) => _migrateBetween(db, from, to),
      ),
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();

  static Future<void> _migrateBetween(Database db, int from, int to) async {
    for (var v = from + 1; v <= to; v++) {
      final step = _migrations[v];
      if (step == null) throw StateError('Missing migration for version $v');
      await step(db);
    }
  }

  /// Version → migration. Add new entries; never edit shipped ones.
  static final Map<int, Future<void> Function(Database)> _migrations = {
    1: _v1,
  };

  static Future<void> _v1(Database db) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE pantry_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity REAL NOT NULL CHECK (quantity >= 0),
        unit TEXT NOT NULL,
        food_state TEXT NOT NULL,
        storage_location TEXT NOT NULL,
        custom_location_name TEXT,
        quality_condition TEXT NOT NULL DEFAULT 'not_assessed',
        freshness TEXT NOT NULL DEFAULT 'not_assessed',
        date_added TEXT NOT NULL,
        purchase_date TEXT,
        expiry_date TEXT,
        date_type TEXT,
        opened_prepared_date TEXT,
        low_stock_threshold REAL CHECK (low_stock_threshold IS NULL OR low_stock_threshold > 0),
        low_stock_unit TEXT,
        notes TEXT,
        photo_path TEXT,
        source_type TEXT NOT NULL DEFAULT 'manual',
        quantity_source TEXT NOT NULL DEFAULT 'user_entered',
        package_content_quantity REAL,
        package_content_unit TEXT,
        barcode TEXT,
        identity_confirmed INTEGER NOT NULL DEFAULT 1,
        is_unavailable INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )''');
    batch.execute(
        'CREATE INDEX idx_pantry_items_name ON pantry_items(normalized_name)');
    batch.execute(
        'CREATE INDEX idx_pantry_items_storage ON pantry_items(storage_location)');
    batch.execute(
        'CREATE INDEX idx_pantry_items_expiry ON pantry_items(expiry_date)');

    batch.execute('''
      CREATE TABLE pantry_item_photos (
        id TEXT PRIMARY KEY,
        pantry_item_id TEXT NOT NULL REFERENCES pantry_items(id) ON DELETE CASCADE,
        file_path TEXT NOT NULL,
        photo_role TEXT,
        created_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE inventory_transactions (
        id TEXT PRIMARY KEY,
        pantry_item_id TEXT NOT NULL,
        item_name TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        quantity_delta REAL,
        unit TEXT NOT NULL,
        quantity_before REAL,
        quantity_after REAL,
        reason TEXT,
        notes TEXT,
        related_cooking_session_id TEXT,
        related_scan_id TEXT,
        created_at TEXT NOT NULL
      )''');
    batch.execute(
        'CREATE INDEX idx_tx_item ON inventory_transactions(pantry_item_id)');
    batch.execute(
        'CREATE INDEX idx_tx_created ON inventory_transactions(created_at)');

    batch.execute('''
      CREATE TABLE capture_drafts (
        id TEXT PRIMARY KEY,
        capture_method TEXT NOT NULL,
        capture_mode TEXT NOT NULL,
        source_photo_path TEXT,
        barcode_value TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE detection_drafts (
        id TEXT PRIMARY KEY,
        capture_draft_id TEXT NOT NULL REFERENCES capture_drafts(id) ON DELETE CASCADE,
        suggested_name TEXT,
        confirmed_name TEXT,
        category TEXT,
        estimated_quantity REAL CHECK (estimated_quantity IS NULL OR estimated_quantity >= 0),
        estimated_unit TEXT,
        quantity_source TEXT NOT NULL,
        food_state TEXT,
        storage_location TEXT,
        custom_location_name TEXT,
        identity_confidence REAL,
        is_identity_confirmed INTEGER NOT NULL DEFAULT 0,
        is_selected INTEGER NOT NULL DEFAULT 1,
        is_removed INTEGER NOT NULL DEFAULT 0,
        quality_condition TEXT NOT NULL DEFAULT 'not_assessed',
        freshness TEXT NOT NULL DEFAULT 'not_assessed',
        date_added TEXT,
        purchase_date TEXT,
        expiry_date TEXT,
        date_type TEXT,
        opened_prepared_date TEXT,
        low_stock_threshold REAL,
        notes TEXT,
        photo_path TEXT,
        barcode TEXT,
        package_content_quantity REAL,
        package_content_unit TEXT,
        merge_target_item_id TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''');
    batch.execute(
        'CREATE INDEX idx_detection_draft ON detection_drafts(capture_draft_id)');

    batch.execute('''
      CREATE TABLE barcode_products (
        barcode TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        brand TEXT,
        category TEXT NOT NULL,
        food_state TEXT NOT NULL,
        unit TEXT NOT NULL,
        package_size_quantity REAL,
        package_size_unit TEXT,
        updated_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE scan_history (
        id TEXT PRIMARY KEY,
        capture_draft_id TEXT,
        capture_method TEXT NOT NULL,
        photo_path TEXT,
        status TEXT NOT NULL,
        confirmed_item_count INTEGER NOT NULL,
        item_names TEXT,
        created_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        summary TEXT,
        meal_type TEXT NOT NULL,
        prep_minutes INTEGER NOT NULL,
        cook_minutes INTEGER NOT NULL,
        difficulty TEXT NOT NULL,
        servings INTEGER NOT NULL,
        cuisine TEXT,
        diet_tags TEXT,
        equipment TEXT,
        image_path TEXT,
        thumbnail_path TEXT,
        optional_note TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE recipe_ingredients (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        ingredient_name TEXT NOT NULL,
        normalized_ingredient_name TEXT NOT NULL,
        match_keys TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        display_quantity TEXT,
        preparation TEXT,
        is_required INTEGER NOT NULL,
        display_order INTEGER NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE recipe_steps (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        step_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        instruction TEXT NOT NULL,
        headline TEXT,
        duration_seconds INTEGER,
        timer_note TEXT
      )''');

    batch.execute('''
      CREATE TABLE meal_preferences (
        id TEXT PRIMARY KEY,
        meal_type_filters TEXT,
        max_time_minutes INTEGER,
        difficulty_filter TEXT,
        dietary_preferences TEXT,
        excluded_ingredients TEXT,
        cuisine_preferences TEXT,
        match_mode TEXT,
        use_soon_first INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE cooking_sessions (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        recipe_name TEXT NOT NULL,
        meal_type TEXT,
        status TEXT NOT NULL,
        servings INTEGER NOT NULL,
        current_step INTEGER NOT NULL,
        completed_steps TEXT,
        timer_remaining_seconds INTEGER,
        started_at TEXT NOT NULL,
        paused_at TEXT,
        completed_at TEXT,
        feedback TEXT,
        is_favorite_saved INTEGER NOT NULL DEFAULT 0,
        notes TEXT
      )''');

    batch.execute('''
      CREATE TABLE cooking_usage (
        id TEXT PRIMARY KEY,
        cooking_session_id TEXT NOT NULL REFERENCES cooking_sessions(id) ON DELETE CASCADE,
        pantry_item_id TEXT,
        ingredient_name TEXT NOT NULL,
        planned_quantity REAL NOT NULL,
        planned_unit TEXT NOT NULL,
        actual_quantity REAL,
        actual_unit TEXT,
        quantity_before REAL,
        quantity_after REAL,
        item_unit TEXT,
        is_skipped INTEGER NOT NULL DEFAULT 0,
        is_confirmed INTEGER NOT NULL DEFAULT 0
      )''');
    await batch.commit(noResult: true);

    await RecipeSeed.insertAll(db);
  }
}
