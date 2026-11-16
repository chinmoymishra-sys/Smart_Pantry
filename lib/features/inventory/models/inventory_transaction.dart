import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';

/// Immutable history record of a change to an inventory item. Transactions
/// describe quantities and actions only — never food safety.
class InventoryTransaction {
  const InventoryTransaction({
    required this.id,
    required this.pantryItemId,
    required this.itemName,
    required this.type,
    required this.unit,
    required this.createdAt,
    this.quantityDelta,
    this.quantityBefore,
    this.quantityAfter,
    this.reason,
    this.notes,
    this.relatedCookingSessionId,
    this.relatedScanId,
  });

  final String id;
  final String pantryItemId;

  /// Name snapshot, so history stays readable after an item is removed.
  final String itemName;
  final TransactionType type;
  final double? quantityDelta;
  final PantryUnit unit;
  final double? quantityBefore;
  final double? quantityAfter;
  final String? reason;
  final String? notes;
  final String? relatedCookingSessionId;
  final String? relatedScanId;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'pantry_item_id': pantryItemId,
        'item_name': itemName,
        'transaction_type': type.dbValue,
        'quantity_delta': quantityDelta,
        'unit': unit.dbValue,
        'quantity_before': quantityBefore,
        'quantity_after': quantityAfter,
        'reason': reason,
        'notes': notes,
        'related_cooking_session_id': relatedCookingSessionId,
        'related_scan_id': relatedScanId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory InventoryTransaction.fromRow(Map<String, Object?> r) =>
      InventoryTransaction(
        id: r['id']! as String,
        pantryItemId: r['pantry_item_id']! as String,
        itemName: r['item_name'] as String? ?? '',
        type: TransactionType.fromDb(r['transaction_type'] as String?),
        quantityDelta: (r['quantity_delta'] as num?)?.toDouble(),
        unit: PantryUnit.fromDb(r['unit'] as String?),
        quantityBefore: (r['quantity_before'] as num?)?.toDouble(),
        quantityAfter: (r['quantity_after'] as num?)?.toDouble(),
        reason: r['reason'] as String?,
        notes: r['notes'] as String?,
        relatedCookingSessionId: r['related_cooking_session_id'] as String?,
        relatedScanId: r['related_scan_id'] as String?,
        createdAt: AppDates.fromDbTimestamp(r['created_at'] as String?) ??
            DateTime.now(),
      );
}
