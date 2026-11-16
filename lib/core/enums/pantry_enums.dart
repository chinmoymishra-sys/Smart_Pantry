/// Domain enums shared by models, controllers and views. Each enum carries a
/// stable `dbValue` for SQLite and a user-facing `label` matching the design.
library;

T _byDb<T>(List<T> values, String? raw, String Function(T) key, T fallback) {
  for (final v in values) {
    if (key(v) == raw) return v;
  }
  return fallback;
}

enum StorageLocation {
  fridge('fridge', 'Fridge'),
  freezer('freezer', 'Freezer'),
  pantry('pantry', 'Pantry'),
  custom('custom', 'Custom');

  const StorageLocation(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static StorageLocation fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, StorageLocation.pantry);
}

enum FoodCategory {
  vegetable('vegetable', 'Vegetable'),
  fruit('fruit', 'Fruit'),
  dairy('dairy', 'Dairy'),
  meat('meat', 'Meat'),
  grain('grain', 'Grain'),
  spice('spice', 'Spice'),
  packaged('packaged', 'Packaged'),
  leftovers('leftovers', 'Leftovers'),
  other('other', 'Other');

  const FoodCategory(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static FoodCategory fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, FoodCategory.other);
}

enum FoodState {
  raw('raw', 'Raw'),
  cooked('cooked', 'Cooked'),
  prepared('prepared', 'Prepared'),
  frozen('frozen', 'Frozen'),
  dried('dried', 'Dried'),
  packaged('packaged', 'Packaged');

  const FoodState(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static FoodState fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, FoodState.raw);
}

/// User-recorded observation. Never set by the app from a photo.
enum Condition {
  notAssessed('not_assessed', 'Not assessed'),
  fresh('fresh', 'Fresh'),
  good('good', 'Good'),
  useSoon('use_soon', 'Use soon'),
  spoiled('spoiled', 'Spoiled / unsafe');

  const Condition(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static Condition fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, Condition.notAssessed);
}

enum DateType {
  useBy('use_by', 'Use by'),
  bestBefore('best_before', 'Best before'),
  expiry('expiry', 'Expiry');

  const DateType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static DateType fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, DateType.useBy);
}

enum SourceType {
  manual('manual', 'Added manually'),
  barcode('barcode', 'Barcode lookup'),
  photoReview('photo_review', 'Reviewed photo capture');

  const SourceType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static SourceType fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, SourceType.manual);
}

/// Whether a quantity was measured/entered by the user or is only a visual
/// estimate. Visual estimates must never be treated as exact measurements.
enum QuantitySource {
  userEntered('user_entered', 'you entered'),
  userMeasured('user_measured', 'you entered after weighing'),
  visualEstimate('visual_estimate', 'visual estimate');

  const QuantitySource(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static QuantitySource fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, QuantitySource.userEntered);
}

enum TransactionType {
  itemAdded('item_added'),
  quantityConsumed('quantity_consumed'),
  quantitySet('quantity_set'),
  moved('moved'),
  markedFinished('marked_finished'),
  discarded('discarded'),
  markedUnavailable('marked_unavailable'),
  markedAvailable('marked_available'),
  itemRemoved('item_removed'),
  itemEdited('item_edited'),
  cookingDeduction('cooking_deduction');

  const TransactionType(this.dbValue);
  final String dbValue;

  static TransactionType fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, TransactionType.itemEdited);
}

enum MealType {
  breakfast('breakfast', 'Breakfast'),
  lunch('lunch', 'Lunch'),
  snacks('snacks', 'Snacks'),
  dinner('dinner', 'Dinner');

  const MealType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static MealType fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, MealType.lunch);
}

enum Difficulty {
  easy('easy', 'Easy'),
  intermediate('intermediate', 'Intermediate');

  const Difficulty(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static Difficulty fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, Difficulty.easy);
}

enum CaptureMode {
  container('container', 'Container'),
  singleItem('single_item', 'Single item'),
  groceries('groceries', 'Groceries');

  const CaptureMode(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static CaptureMode fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, CaptureMode.groceries);
}

enum CaptureMethod {
  camera('camera', 'Camera'),
  upload('upload', 'Upload'),
  barcode('barcode', 'Barcode / QR'),
  manual('manual', 'Manual');

  const CaptureMethod(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static CaptureMethod fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, CaptureMethod.manual);
}

enum CookingStatus {
  active('active'),
  paused('paused'),
  awaitingReview('awaiting_review'),
  completed('completed'),
  completedWithoutUpdate('completed_without_update'),
  abandoned('abandoned');

  const CookingStatus(this.dbValue);
  final String dbValue;

  bool get isOpen =>
      this == active || this == paused || this == awaitingReview;

  static CookingStatus fromDb(String? raw) =>
      _byDb(values, raw, (v) => v.dbValue, CookingStatus.active);
}

enum CookingFeedback {
  likedIt('liked_it', 'Liked it'),
  notForMe('not_for_me', 'Not for me'),
  cookAgain('cook_again', 'Cook again');

  const CookingFeedback(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static CookingFeedback? fromDb(String? raw) {
    for (final v in values) {
      if (v.dbValue == raw) return v;
    }
    return null;
  }
}
