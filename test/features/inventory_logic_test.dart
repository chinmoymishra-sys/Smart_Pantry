import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pantry/core/enums/pantry_enums.dart';
import 'package:smart_pantry/core/utils/units.dart';
import 'package:smart_pantry/features/inventory/controllers/inventory_controller.dart';
import 'package:smart_pantry/features/inventory/models/pantry_item.dart';

import '../helpers/fixtures.dart';

void main() {
  setUp(pinToday);

  late List<PantryItem> items;
  setUp(() {
    items = [
      item('Spinach', 150, PantryUnit.g, expiry: DateTime(2026, 11, 8)),
      item('Plain yogurt', 400, PantryUnit.g, expiry: DateTime(2026, 11, 9)),
      item('Tomatoes', 4, PantryUnit.pieces, expiry: DateTime(2026, 11, 11)),
      item('Green peas', 300, PantryUnit.g, storage: StorageLocation.freezer),
      item('Rice', 1, PantryUnit.kg, storage: StorageLocation.pantry),
      item('Olive oil', 50, PantryUnit.ml,
          storage: StorageLocation.pantry, lowStock: 60),
      item('Old milk', 1, PantryUnit.l, expiry: DateTime(2026, 11, 2)),
      item('Flour', 0, PantryUnit.g, storage: StorageLocation.pantry),
    ];
  });

  test('summary counts unique records, not quantities', () {
    final s = InventorySummary.of(items);
    expect(s.total, 8);
    expect(s.fridge, 4);
    expect(s.freezer, 1);
    expect(s.pantry, 3);
  });

  test('use soon is within 3 days of a recorded date', () {
    final s = InventorySummary.of(items);
    expect(s.useSoon.map((i) => i.name), ['Spinach', 'Plain yogurt']);
    expect(items.firstWhere((i) => i.name == 'Tomatoes').isUseSoon, isFalse);
    expect(items.firstWhere((i) => i.name == 'Green peas').isUseSoon, isFalse);
  });

  test('low stock uses the user threshold in a compatible unit', () {
    expect(InventorySummary.of(items).lowStock.single.name, 'Olive oil');
    final kgThreshold = item('Sugar', 400, PantryUnit.g, lowStock: 0.5)
        .copyWith(lowStockUnit: PantryUnit.kg);
    expect(kgThreshold.isLowStock, isTrue);
  });

  test('out is distinct from deleted', () {
    expect(InventorySummary.of(items).out.single.name, 'Flour');
  });

  test('expiry sort puts undated items last', () {
    final sorted = const InventoryFilter().apply(items);
    expect(sorted.first.name, 'Old milk');
    expect(sorted.take(4).map((i) => i.name),
        ['Old milk', 'Spinach', 'Plain yogurt', 'Tomatoes']);
    expect(sorted.skip(4).every((i) => i.expiryDate == null), isTrue);
  });

  test('quantity sort groups compatible units', () {
    final sorted =
        const InventoryFilter(sort: InventorySort.quantity).apply(items);
    final kinds = sorted.map((i) => i.unit.kind).toList();
    // Count units come first as their own group, then mass, then volume.
    final firstMass = kinds.indexOf(UnitKind.weight);
    final lastMass = kinds.lastIndexOf(UnitKind.weight);
    expect(kinds.sublist(firstMass, lastMass + 1).every((k) => k == UnitKind.weight),
        isTrue);
    // 1 kg rice ranks above 400 g yogurt.
    expect(sorted.indexWhere((i) => i.name == 'Rice'),
        lessThan(sorted.indexWhere((i) => i.name == 'Plain yogurt')));
  });

  test('filters: search, storage, date and stock', () {
    expect(const InventoryFilter(query: 'pea').apply(items).single.name,
        'Green peas');
    expect(
        const InventoryFilter(storage: StorageLocation.pantry)
            .apply(items)
            .length,
        3);
    expect(const InventoryFilter(date: DateFilter.pastDate).apply(items).single.name,
        'Old milk');
    expect(const InventoryFilter(date: DateFilter.noDate).apply(items).length, 4);
    expect(const InventoryFilter(stock: StockFilter.low).apply(items).single.name,
        'Olive oil');
  });

  test('quality defaults to not assessed', () {
    expect(items.first.condition, Condition.notAssessed);
    expect(items.first.freshness, Condition.notAssessed);
  });
}
