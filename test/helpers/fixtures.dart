import 'package:smart_pantry/core/enums/pantry_enums.dart';
import 'package:smart_pantry/core/utils/dates.dart';
import 'package:smart_pantry/core/utils/units.dart';
import 'package:smart_pantry/features/inventory/models/pantry_item.dart';

int _seq = 0;

PantryItem item(
  String name,
  double qty,
  PantryUnit unit, {
  StorageLocation storage = StorageLocation.fridge,
  FoodState state = FoodState.raw,
  FoodCategory category = FoodCategory.vegetable,
  DateTime? expiry,
  double? lowStock,
  bool unavailable = false,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2026, 11, 6, 8, _seq++);
  return PantryItem(
    id: 'id-$name-${_seq++}',
    name: name,
    category: category,
    quantity: qty,
    unit: unit,
    foodState: state,
    storage: storage,
    dateAdded: AppDates.today(),
    expiryDate: expiry,
    lowStockThreshold: lowStock,
    lowStockUnit: lowStock == null ? null : unit,
    isUnavailable: unavailable,
    createdAt: now,
    updatedAt: now,
  );
}

/// Pins "today" to Friday 6 Nov 2026 (the design's reference date).
void pinToday() {
  AppDates.clock = () => DateTime(2026, 11, 6, 12);
}
