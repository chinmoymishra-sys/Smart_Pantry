import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums/pantry_enums.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/units.dart';
import '../../features/cooking/models/cooking_models.dart';
import '../../features/cooking/repositories/cooking_repository.dart';
import '../../features/inventory/models/inventory_transaction.dart';
import '../../features/inventory/models/pantry_item.dart';

class SqliteCookingRepository implements CookingRepository {
  SqliteCookingRepository(this._db);
  final Database _db;
  static const _uuid = Uuid();

  /// Upsert without REPLACE: a REPLACE would delete the row and cascade-
  /// delete its cooking_usage history.
  static Future<void> _upsertSession(
      DatabaseExecutor db, CookingSession session) async {
    final updated = await db.update('cooking_sessions', session.toRow(),
        where: 'id = ?', whereArgs: [session.id]);
    if (updated == 0) await db.insert('cooking_sessions', session.toRow());
  }

  @override
  Future<void> saveSession(CookingSession session) =>
      _upsertSession(_db, session);

  @override
  Future<CookingSession?> getSession(String id) async {
    final rows = await _db.query('cooking_sessions',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : CookingSession.fromRow(rows.first);
  }

  @override
  Future<CookingSession?> getOpenSession() async {
    final rows = await _db.query(
      'cooking_sessions',
      where: 'status IN (?, ?, ?)',
      whereArgs: [
        CookingStatus.active.dbValue,
        CookingStatus.paused.dbValue,
        CookingStatus.awaitingReview.dbValue,
      ],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : CookingSession.fromRow(rows.first);
  }

  @override
  Future<List<CookingSession>> getHistory() async {
    final rows = await _db.query(
      'cooking_sessions',
      where: 'status IN (?, ?)',
      whereArgs: [
        CookingStatus.completed.dbValue,
        CookingStatus.completedWithoutUpdate.dbValue,
      ],
      orderBy: 'completed_at DESC',
    );
    return rows.map(CookingSession.fromRow).toList();
  }

  @override
  Future<List<CookingUsage>> getUsage(String sessionId) async {
    final rows = await _db.query('cooking_usage',
        where: 'cooking_session_id = ?', whereArgs: [sessionId]);
    return rows.map(CookingUsage.fromRow).toList();
  }

  @override
  Future<CookingSession> confirmDeductions(
    CookingSession session,
    List<DeductionProposal> proposals,
  ) async {
    for (final p in proposals) {
      if (p.skipped) continue;
      if (p.used < 0) {
        throw ValidationException('Amounts can’t be negative.');
      }
      if (p.hasUnitProblem) {
        throw ValidationException(
            '${p.itemName}: use ${p.itemUnit.dbValue} or a compatible unit.');
      }
      if (p.exceedsStock) {
        throw ValidationException(
            '${p.itemName}: you only have ${formatQuantity(p.before, p.itemUnit)}. '
            'Correct the amount or skip it.');
      }
    }
    final now = DateTime.now();
    final completed = session.copyWith(
      status: CookingStatus.completed,
      completedAt: now,
      timerRunning: false,
      clearTimer: true,
    );
    await _db.transaction((txn) async {
      for (final p in proposals) {
        final rows = await txn.query('pantry_items',
            where: 'id = ? AND deleted_at IS NULL',
            whereArgs: [p.pantryItemId],
            limit: 1);
        if (rows.isEmpty) {
          throw NotFoundException('${p.itemName} is no longer in inventory.');
        }
        final item = PantryItem.fromRow(rows.first);
        double? after;
        if (!p.skipped) {
          final used = p.usedInItemUnit!;
          // Re-validate against the live balance inside the transaction.
          if (used > item.quantity + 1e-9) {
            throw ValidationException(
                '${item.name}: only ${item.quantityLabel} left now.');
          }
          after = ((item.quantity - used) * 1000).roundToDouble() / 1000;
          if (used > 0) {
            await txn.update(
              'pantry_items',
              item.copyWith(quantity: after, updatedAt: now).toRow(),
              where: 'id = ?',
              whereArgs: [item.id],
            );
            await txn.insert(
              'inventory_transactions',
              InventoryTransaction(
                id: _uuid.v4(),
                pantryItemId: item.id,
                itemName: item.name,
                type: TransactionType.cookingDeduction,
                unit: item.unit,
                quantityDelta: -used,
                quantityBefore: item.quantity,
                quantityAfter: after,
                notes: session.recipeName,
                relatedCookingSessionId: session.id,
                createdAt: now,
              ).toRow(),
            );
          }
        }
        await txn.insert(
          'cooking_usage',
          CookingUsage(
            id: _uuid.v4(),
            cookingSessionId: session.id,
            pantryItemId: item.id,
            ingredientName: p.ingredientName,
            plannedQuantity: p.plannedQuantity,
            plannedUnit: p.plannedUnit,
            actualQuantity: p.skipped ? null : p.used,
            actualUnit: p.skipped ? null : p.usedUnit,
            quantityBefore: item.quantity,
            quantityAfter: after ?? item.quantity,
            itemUnit: item.unit,
            isSkipped: p.skipped,
            isConfirmed: true,
          ).toRow(),
        );
      }
      await _upsertSession(txn, completed);
    });
    return completed;
  }
}
