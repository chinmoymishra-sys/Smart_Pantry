import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/units.dart';
import '../models/inventory_transaction.dart';
import '../models/pantry_item.dart';

/// Inventory operations. Every quantity-changing method writes a matching
/// [InventoryTransaction] inside the same SQLite transaction.
abstract interface class PantryRepository {
  Future<List<PantryItem>> getItems();
  Future<PantryItem?> getItem(String id);
  Future<List<InventoryTransaction>> getTransactions({int? limit});

  /// Edit details (name, category, dates, condition, notes, photo, …).
  /// Quantity changes must use the dedicated methods below.
  Future<PantryItem> updateDetails(PantryItem item);

  /// Records an amount used. Rejects negatives and amounts above stock.
  Future<PantryItem> consume(String id, double amount, PantryUnit unit);

  /// Replaces the measured balance (not recorded as consumption).
  Future<PantryItem> setQuantity(String id, double quantity, PantryUnit unit);

  /// Changes storage only — never food state or expiry.
  Future<PantryItem> move(
    String id,
    StorageLocation to, {
    String? customLocationName,
  });

  Future<PantryItem> markFinished(String id);
  Future<PantryItem> discard(String id, {String? reason});
  Future<PantryItem> setUnavailable(String id, bool unavailable);

  /// Permanently deletes the record and its photo file.
  Future<void> remove(String id);
}
