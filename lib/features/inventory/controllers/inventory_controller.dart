import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/units.dart';
import '../../../providers/repository_providers.dart';
import '../models/inventory_transaction.dart';
import '../models/pantry_item.dart';

/// Loads confirmed inventory and coordinates every lifecycle mutation.
/// Mutations throw on validation errors; on failure the last loaded list is
/// preserved.
class InventoryController extends AsyncNotifier<List<PantryItem>> {
  bool _busy = false;

  @override
  Future<List<PantryItem>> build() =>
      ref.read(pantryRepositoryProvider).getItems();

  Future<void> refresh() async {
    final repo = ref.read(pantryRepositoryProvider);
    try {
      final items = await repo.getItems();
      state = AsyncData(items);
    } catch (e, st) {
      // Keep showing the previous data if a background refresh fails.
      if (!state.hasValue) state = AsyncError(e, st);
    }
    ref.invalidate(inventoryTransactionsProvider);
  }

  Future<T> _mutate<T>(Future<T> Function() action) async {
    if (_busy) throw StateError('Another change is still saving.');
    _busy = true;
    try {
      final result = await action();
      await refresh();
      return result;
    } finally {
      _busy = false;
    }
  }

  Future<PantryItem> updateDetails(PantryItem item) =>
      _mutate(() => ref.read(pantryRepositoryProvider).updateDetails(item));

  Future<PantryItem> consume(String id, double amount, PantryUnit unit) =>
      _mutate(() => ref.read(pantryRepositoryProvider).consume(id, amount, unit));

  Future<PantryItem> setQuantity(String id, double qty, PantryUnit unit) =>
      _mutate(() => ref.read(pantryRepositoryProvider).setQuantity(id, qty, unit));

  Future<PantryItem> move(String id, StorageLocation to, {String? customName}) =>
      _mutate(() => ref
          .read(pantryRepositoryProvider)
          .move(id, to, customLocationName: customName));

  Future<PantryItem> markFinished(String id) =>
      _mutate(() => ref.read(pantryRepositoryProvider).markFinished(id));

  Future<PantryItem> discard(String id, {String? reason}) =>
      _mutate(() => ref.read(pantryRepositoryProvider).discard(id, reason: reason));

  Future<PantryItem> setUnavailable(String id, bool unavailable) => _mutate(
      () => ref.read(pantryRepositoryProvider).setUnavailable(id, unavailable));

  Future<void> remove(String id) =>
      _mutate(() => ref.read(pantryRepositoryProvider).remove(id));

  /// Copies a picked image into app-managed storage and returns the stored
  /// path. Nothing is written to inventory until [updateDetails] is called.
  Future<String> importPhoto(String path) =>
      ref.read(photoStorageProvider).importPhoto(path);

  /// Deletes an imported photo that was never saved to an item (e.g. when
  /// saving the item details failed). Only app-managed files are touched.
  Future<void> discardImportedPhoto(String path) =>
      ref.read(photoStorageProvider).delete(path);
}

final inventoryProvider =
    AsyncNotifierProvider<InventoryController, List<PantryItem>>(
        InventoryController.new);

final inventoryTransactionsProvider =
    FutureProvider<List<InventoryTransaction>>(
        (ref) => ref.watch(pantryRepositoryProvider).getTransactions());

final pantryItemProvider = Provider.family<PantryItem?, String>((ref, id) {
  final items = ref.watch(inventoryProvider).value;
  if (items == null) return null;
  for (final i in items) {
    if (i.id == id) return i;
  }
  return null;
});

// ---------------------------------------------------------------------------
// Summary (derived; never stored)

class InventorySummary {
  const InventorySummary({
    required this.total,
    required this.fridge,
    required this.freezer,
    required this.pantry,
    required this.custom,
    required this.useSoon,
    required this.lowStock,
    required this.out,
  });

  /// Unique food records — not a sum of quantities.
  final int total;
  final int fridge;
  final int freezer;
  final int pantry;
  final int custom;
  final List<PantryItem> useSoon;
  final List<PantryItem> lowStock;
  final List<PantryItem> out;

  static InventorySummary of(List<PantryItem> items) {
    int count(StorageLocation l) => items.where((i) => i.storage == l).length;
    final useSoon = items.where((i) => i.isUseSoon).toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    return InventorySummary(
      total: items.length,
      fridge: count(StorageLocation.fridge),
      freezer: count(StorageLocation.freezer),
      pantry: count(StorageLocation.pantry),
      custom: count(StorageLocation.custom),
      useSoon: useSoon,
      lowStock: items.where((i) => i.isLowStock).toList(),
      out: items.where((i) => i.isOut || i.isUnavailable).toList(),
    );
  }
}

final inventorySummaryProvider = Provider<AsyncValue<InventorySummary>>(
  (ref) => ref.watch(inventoryProvider).whenData(InventorySummary.of),
);

// ---------------------------------------------------------------------------
// Filters

enum DateFilter {
  any('Any date'),
  within3Days('Within 3 days'),
  pastDate('Past date'),
  noDate('No date');

  const DateFilter(this.label);
  final String label;
}

enum StockFilter {
  all('All stock'),
  low('Low'),
  out('Out / unavailable');

  const StockFilter(this.label);
  final String label;
}

enum InventorySort {
  expiry('Earliest expiry', 'expiry'),
  name('Name A–Z', 'name'),
  recent('Recently added', 'recent'),
  quantity('Quantity', 'quantity');

  const InventorySort(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

class InventoryFilter {
  const InventoryFilter({
    this.query = '',
    this.storage,
    this.category,
    this.foodState,
    this.condition,
    this.date = DateFilter.any,
    this.stock = StockFilter.all,
    this.sort = InventorySort.expiry,
  });

  final String query;

  /// null = All storage.
  final StorageLocation? storage;
  final FoodCategory? category;
  final FoodState? foodState;
  final Condition? condition;
  final DateFilter date;
  final StockFilter stock;
  final InventorySort sort;

  int get activeCount =>
      (category != null ? 1 : 0) +
      (foodState != null ? 1 : 0) +
      (condition != null ? 1 : 0) +
      (date != DateFilter.any ? 1 : 0) +
      (stock != StockFilter.all ? 1 : 0);

  InventoryFilter copyWith({
    String? query,
    StorageLocation? storage,
    bool clearStorage = false,
    FoodCategory? category,
    bool clearCategory = false,
    FoodState? foodState,
    bool clearFoodState = false,
    Condition? condition,
    bool clearCondition = false,
    DateFilter? date,
    StockFilter? stock,
    InventorySort? sort,
  }) =>
      InventoryFilter(
        query: query ?? this.query,
        storage: clearStorage ? null : (storage ?? this.storage),
        category: clearCategory ? null : (category ?? this.category),
        foodState: clearFoodState ? null : (foodState ?? this.foodState),
        condition: clearCondition ? null : (condition ?? this.condition),
        date: date ?? this.date,
        stock: stock ?? this.stock,
        sort: sort ?? this.sort,
      );

  bool matches(PantryItem i) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty && !i.normalizedName.contains(q)) return false;
    if (storage != null && i.storage != storage) return false;
    if (category != null && i.category != category) return false;
    if (foodState != null && i.foodState != foodState) return false;
    if (condition != null &&
        i.condition != condition &&
        i.freshness != condition) {
      return false;
    }
    switch (date) {
      case DateFilter.any:
        break;
      case DateFilter.within3Days:
        if (!i.isUseSoon) return false;
      case DateFilter.pastDate:
        if (!i.isPastDate) return false;
      case DateFilter.noDate:
        if (i.expiryDate != null) return false;
    }
    switch (stock) {
      case StockFilter.all:
        break;
      case StockFilter.low:
        if (!i.isLowStock) return false;
      case StockFilter.out:
        if (!(i.isOut || i.isUnavailable)) return false;
    }
    return true;
  }

  List<PantryItem> apply(List<PantryItem> items) {
    final list = items.where(matches).toList();
    switch (sort) {
      case InventorySort.expiry:
        // Undated items come last.
        list.sort((a, b) {
          final ad = a.expiryDate, bd = b.expiryDate;
          if (ad == null && bd == null) return a.name.compareTo(b.name);
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });
      case InventorySort.name:
        list.sort((a, b) => a.normalizedName.compareTo(b.normalizedName));
      case InventorySort.recent:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case InventorySort.quantity:
        // Group compatible units (weight, volume, then each count unit),
        // then sort by normalised base quantity within the group.
        String group(PantryItem i) => i.unit.kind == UnitKind.count
            ? 'c:${i.unit.dbValue}'
            : 'm:${i.unit.kind.name}';
        list.sort((a, b) {
          final g = group(a).compareTo(group(b));
          if (g != 0) return g;
          return (b.quantity * b.unit.toBase)
              .compareTo(a.quantity * a.unit.toBase);
        });
    }
    return list;
  }
}

class InventoryFilterController extends Notifier<InventoryFilter> {
  @override
  InventoryFilter build() => const InventoryFilter();

  void set(InventoryFilter f) => state = f;
  void setQuery(String q) => state = state.copyWith(query: q);
  void setStorage(StorageLocation? s) =>
      state = state.copyWith(storage: s, clearStorage: s == null);
  void reset() => state = InventoryFilter(query: state.query);
}

final inventoryFilterProvider =
    NotifierProvider<InventoryFilterController, InventoryFilter>(
        InventoryFilterController.new);

final filteredInventoryProvider = Provider<AsyncValue<List<PantryItem>>>((ref) {
  final filter = ref.watch(inventoryFilterProvider);
  return ref.watch(inventoryProvider).whenData(filter.apply);
});
