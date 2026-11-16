import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums/pantry_enums.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/units.dart';
import '../../features/inventory/models/inventory_transaction.dart';
import '../../features/inventory/models/pantry_item.dart';
import '../../features/inventory/repositories/pantry_repository.dart';
import '../services/photo_storage.dart';

class SqlitePantryRepository implements PantryRepository {
  SqlitePantryRepository(this._db, this._photos);

  final Database _db;
  final PhotoStorage _photos;
  static const _uuid = Uuid();

  @override
  Future<List<PantryItem>> getItems() async {
    final rows = await _db.query(
      'pantry_items',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map(PantryItem.fromRow).toList();
  }

  @override
  Future<PantryItem?> getItem(String id) async {
    final rows = await _db.query(
      'pantry_items',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : PantryItem.fromRow(rows.first);
  }

  @override
  Future<List<InventoryTransaction>> getTransactions({int? limit}) async {
    final rows = await _db.query(
      'inventory_transactions',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(InventoryTransaction.fromRow).toList();
  }

  Future<PantryItem> _require(DatabaseExecutor txn, String id) async {
    final rows = await txn.query('pantry_items',
        where: 'id = ? AND deleted_at IS NULL', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw NotFoundException('This item no longer exists.');
    return PantryItem.fromRow(rows.first);
  }

  Future<void> _writeTx(
    DatabaseExecutor txn,
    PantryItem item,
    TransactionType type, {
    double? delta,
    double? before,
    double? after,
    String? reason,
    String? notes,
  }) =>
      txn.insert(
        'inventory_transactions',
        InventoryTransaction(
          id: _uuid.v4(),
          pantryItemId: item.id,
          itemName: item.name,
          type: type,
          unit: item.unit,
          quantityDelta: delta,
          quantityBefore: before,
          quantityAfter: after,
          reason: reason,
          notes: notes,
          createdAt: DateTime.now(),
        ).toRow(),
      );

  Future<PantryItem> _saveItem(DatabaseExecutor txn, PantryItem item) async {
    final updated = item.copyWith(updatedAt: DateTime.now());
    await txn.update('pantry_items', updated.toRow(),
        where: 'id = ?', whereArgs: [item.id]);
    return updated;
  }

  @override
  Future<PantryItem> updateDetails(PantryItem item) async {
    if (item.name.trim().isEmpty) {
      throw ValidationException('Enter a name for this item.');
    }
    if (item.lowStockThreshold != null && item.lowStockThreshold! <= 0) {
      throw ValidationException('Low-stock threshold must be above zero.');
    }
    return _db.transaction((txn) async {
      final current = await _require(txn, item.id);
      final previousPhoto = current.photoPath;
      // Quantity is not editable through details.
      final saved = await _saveItem(
        txn,
        item.copyWith(quantity: current.quantity, unit: current.unit),
      );
      await _writeTx(txn, saved, TransactionType.itemEdited);
      if (previousPhoto != null && previousPhoto != saved.photoPath) {
        await _photos.delete(previousPhoto);
      }
      return saved;
    });
  }

  @override
  Future<PantryItem> consume(String id, double amount, PantryUnit unit) async {
    if (amount.isNaN || amount <= 0) {
      throw ValidationException('Enter an amount above zero.');
    }
    return _db.transaction((txn) async {
      final item = await _require(txn, id);
      final used = tryConvertQuantity(amount, unit, item.unit);
      if (used == null) {
        throw ValidationException(
            'Use ${item.unit.dbValue} or a compatible unit for ${item.name}.');
      }
      if (used > item.quantity + 1e-9) {
        throw ValidationException(
            'You only have ${item.quantityLabel}. Use Set quantity to correct the balance.');
      }
      final after = _round(item.quantity - used);
      final saved = await _saveItem(txn, item.copyWith(quantity: after));
      await _writeTx(txn, saved, TransactionType.quantityConsumed,
          delta: -used, before: item.quantity, after: after);
      return saved;
    });
  }

  @override
  Future<PantryItem> setQuantity(String id, double quantity, PantryUnit unit) async {
    if (quantity.isNaN || quantity < 0) {
      throw ValidationException('Quantity can’t be negative.');
    }
    return _db.transaction((txn) async {
      final item = await _require(txn, id);
      // Setting a new balance may also change the unit explicitly.
      final saved = await _saveItem(
        txn,
        item.copyWith(
          quantity: quantity,
          unit: unit,
          quantitySource: QuantitySource.userEntered,
        ),
      );
      await _writeTx(txn, saved, TransactionType.quantitySet,
          before: item.unit == unit ? item.quantity : null,
          after: quantity,
          notes: item.unit == unit
              ? null
              : 'Unit changed from ${item.unit.dbValue} to ${unit.dbValue}');
      return saved;
    });
  }

  @override
  Future<PantryItem> move(String id, StorageLocation to,
      {String? customLocationName}) async {
    if (to == StorageLocation.custom &&
        (customLocationName == null || customLocationName.trim().isEmpty)) {
      throw ValidationException('Name the custom location.');
    }
    return _db.transaction((txn) async {
      final item = await _require(txn, id);
      final from = item.storageLabel;
      final saved = await _saveItem(
        txn,
        item.copyWith(
          storage: to,
          customLocationName:
              to == StorageLocation.custom ? customLocationName!.trim() : null,
          clearCustomLocation: to != StorageLocation.custom,
        ),
      );
      await _writeTx(txn, saved, TransactionType.moved,
          notes: '$from → ${saved.storageLabel}');
      return saved;
    });
  }

  @override
  Future<PantryItem> markFinished(String id) => _db.transaction((txn) async {
        final item = await _require(txn, id);
        final saved = await _saveItem(txn, item.copyWith(quantity: 0));
        await _writeTx(txn, saved, TransactionType.markedFinished,
            delta: -item.quantity, before: item.quantity, after: 0);
        return saved;
      });

  @override
  Future<PantryItem> discard(String id, {String? reason}) =>
      _db.transaction((txn) async {
        final item = await _require(txn, id);
        final saved = await _saveItem(txn, item.copyWith(quantity: 0));
        await _writeTx(txn, saved, TransactionType.discarded,
            delta: -item.quantity,
            before: item.quantity,
            after: 0,
            reason: reason?.trim().isEmpty ?? true ? null : reason!.trim());
        return saved;
      });

  @override
  Future<PantryItem> setUnavailable(String id, bool unavailable) =>
      _db.transaction((txn) async {
        final item = await _require(txn, id);
        final saved =
            await _saveItem(txn, item.copyWith(isUnavailable: unavailable));
        await _writeTx(
          txn,
          saved,
          unavailable
              ? TransactionType.markedUnavailable
              : TransactionType.markedAvailable,
        );
        return saved;
      });

  @override
  Future<void> remove(String id) async {
    String? photo;
    await _db.transaction((txn) async {
      final item = await _require(txn, id);
      photo = item.photoPath;
      await _writeTx(txn, item, TransactionType.itemRemoved,
          before: item.quantity);
      await txn.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
    });
    if (photo != null) await _photos.delete(photo!);
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}
