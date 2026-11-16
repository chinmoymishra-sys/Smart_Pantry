import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/enums/pantry_enums.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/units.dart';
import '../../features/capture/models/capture_models.dart';
import '../../features/capture/repositories/capture_repository.dart';
import '../../features/inventory/models/inventory_transaction.dart';
import '../../features/inventory/models/pantry_item.dart';
import '../services/photo_storage.dart';

class SqliteCaptureRepository implements CaptureRepository {
  SqliteCaptureRepository(this._db, this._photos);

  final Database _db;
  final PhotoStorage _photos;
  static const _uuid = Uuid();

  @override
  Future<CaptureDraft> createDraft({
    required CaptureMethod method,
    CaptureMode mode = CaptureMode.groceries,
    String? photoPath,
    String? barcode,
  }) async {
    // Only one open draft at a time: cancel any stale one first.
    final existing = await loadOpenDraft();
    if (existing != null) await cancelDraft(existing.id);
    final now = DateTime.now();
    final draft = CaptureDraft(
      id: _uuid.v4(),
      method: method,
      mode: mode,
      sourcePhotoPath: photoPath,
      barcodeValue: barcode,
      status: CaptureDraftStatus.open,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('capture_drafts', draft.toRow());
    return draft;
  }

  @override
  Future<CaptureDraft?> loadOpenDraft() async {
    final rows = await _db.query('capture_drafts',
        where: 'status = ?',
        whereArgs: [CaptureDraftStatus.open.dbValue],
        orderBy: 'updated_at DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    final id = rows.first['id']! as String;
    final det = await _db.query('detection_drafts',
        where: 'capture_draft_id = ? AND is_removed = 0',
        whereArgs: [id],
        orderBy: 'sort_order ASC, created_at ASC');
    return CaptureDraft.fromRow(
        rows.first, det.map(DetectionDraft.fromRow).toList());
  }

  @override
  Future<void> saveDraft(CaptureDraft draft) => _db.transaction((txn) async {
        final row = draft.copyWith(updatedAt: DateTime.now()).toRow();
        final n = await txn.update('capture_drafts', row,
            where: 'id = ?', whereArgs: [draft.id]);
        if (n == 0) await txn.insert('capture_drafts', row);
        await txn.delete('detection_drafts',
            where: 'capture_draft_id = ?', whereArgs: [draft.id]);
        for (final d in draft.detections) {
          await txn.insert('detection_drafts', d.toRow());
        }
      });

  @override
  Future<void> cancelDraft(String draftId) async {
    final rows = await _db.query('capture_drafts',
        where: 'id = ?', whereArgs: [draftId], limit: 1);
    if (rows.isEmpty) return;
    final draft = CaptureDraft.fromRow(rows.first, const []);
    final dets = await _db.query('detection_drafts',
        columns: ['photo_path'],
        where: 'capture_draft_id = ?',
        whereArgs: [draftId]);
    await _db.transaction((txn) async {
      await txn.delete('detection_drafts',
          where: 'capture_draft_id = ?', whereArgs: [draftId]);
      await txn.delete('capture_drafts', where: 'id = ?', whereArgs: [draftId]);
    });
    final photos = {
      draft.sourcePhotoPath,
      ...dets.map((r) => r['photo_path'] as String?),
    }.whereType<String>();
    for (final ph in photos) {
      await _photos.delete(ph);
    }
  }

  @override
  Future<CommitResult> commitDraft(CaptureDraft draft) async {
    final selected = draft.selected;
    if (selected.isEmpty) {
      throw ValidationException('Select at least one item to save.');
    }
    final unresolved = draft.unresolved;
    if (unresolved.isNotEmpty) {
      throw ValidationException(
          'Confirm “${unresolved.first.displayName}” before saving.');
    }

    final now = DateTime.now();
    final ids = <String>[];
    var added = 0, merged = 0;
    final scanId = draft.method == CaptureMethod.manual ? null : _uuid.v4();

    await _db.transaction((txn) async {
      for (final d in selected) {
        final qty = d.quantity!;
        if (d.mergeTargetItemId != null) {
          final rows = await txn.query('pantry_items',
              where: 'id = ? AND deleted_at IS NULL',
              whereArgs: [d.mergeTargetItemId],
              limit: 1);
          if (rows.isEmpty) {
            throw NotFoundException(
                'The item to merge “${d.name}” into no longer exists.');
          }
          final target = PantryItem.fromRow(rows.first);
          final addQty = tryConvertQuantity(qty, d.unit, target.unit);
          if (addQty == null) {
            throw ValidationException(
                'Can’t merge ${d.unit.dbValue} into ${target.unit.dbValue}.');
          }
          final after = target.quantity + addQty;
          await txn.update(
            'pantry_items',
            target
                .copyWith(quantity: after, isUnavailable: false, updatedAt: now)
                .toRow(),
            where: 'id = ?',
            whereArgs: [target.id],
          );
          await txn.insert(
            'inventory_transactions',
            InventoryTransaction(
              id: _uuid.v4(),
              pantryItemId: target.id,
              itemName: target.name,
              type: TransactionType.itemAdded,
              unit: target.unit,
              quantityDelta: addQty,
              quantityBefore: target.quantity,
              quantityAfter: after,
              notes: 'Merged after review',
              relatedScanId: scanId,
              createdAt: now,
            ).toRow(),
          );
          ids.add(target.id);
          merged++;
        } else {
          final photo = d.photoPath;
          final item = PantryItem(
            id: _uuid.v4(),
            name: d.name.trim(),
            category: d.category,
            quantity: qty,
            unit: d.unit,
            foodState: d.foodState,
            storage: d.storage,
            customLocationName: d.customLocationName,
            condition: d.condition,
            freshness: d.freshness,
            dateAdded: d.dateAdded ?? AppDates.today(),
            purchaseDate: d.purchaseDate,
            expiryDate: d.expiryDate,
            dateType: d.dateType,
            openedDate: d.openedDate,
            lowStockThreshold: d.lowStockThreshold,
            lowStockUnit: d.lowStockThreshold == null ? null : d.unit,
            notes: d.notes?.trim().isEmpty ?? true ? null : d.notes!.trim(),
            photoPath: photo,
            sourceType: switch (draft.method) {
              CaptureMethod.barcode => SourceType.barcode,
              CaptureMethod.manual => SourceType.manual,
              _ => SourceType.photoReview,
            },
            quantitySource: d.quantitySource == QuantitySource.visualEstimate
                ? QuantitySource.userEntered
                : d.quantitySource,
            packageContentQuantity: d.packageContentQuantity,
            packageContentUnit: d.packageContentUnit,
            barcode: d.barcode,
            createdAt: now,
            updatedAt: now,
          );
          await txn.insert('pantry_items', item.toRow());
          if (photo != null) {
            await txn.insert('pantry_item_photos', {
              'id': _uuid.v4(),
              'pantry_item_id': item.id,
              'file_path': photo,
              'photo_role': 'item',
              'created_at': now.toUtc().toIso8601String(),
            });
          }
          await txn.insert(
            'inventory_transactions',
            InventoryTransaction(
              id: _uuid.v4(),
              pantryItemId: item.id,
              itemName: item.name,
              type: TransactionType.itemAdded,
              unit: item.unit,
              quantityDelta: qty,
              quantityBefore: 0,
              quantityAfter: qty,
              notes: draft.method == CaptureMethod.manual
                  ? null
                  : 'Added after review',
              relatedScanId: scanId,
              createdAt: now,
            ).toRow(),
          );
          ids.add(item.id);
          added++;
        }
        if (d.barcode != null && d.barcode!.isNotEmpty) {
          await txn.insert(
            'barcode_products',
            BarcodeProduct(
              barcode: d.barcode!,
              name: d.name.trim(),
              category: d.category,
              foodState: d.foodState,
              unit: d.unit,
              packageSizeQuantity: d.packageContentQuantity,
              packageSizeUnit: d.packageContentUnit,
              updatedAt: now,
            ).toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      if (scanId != null) {
        await txn.insert('scan_history', {
          'id': scanId,
          'capture_draft_id': draft.id,
          'capture_method': draft.method.dbValue,
          'photo_path': draft.sourcePhotoPath,
          'status': 'saved',
          'confirmed_item_count': selected.length,
          'item_names': selected.map((d) => d.name.trim()).join('\n'),
          'created_at': now.toUtc().toIso8601String(),
        });
      }
      await txn.update(
        'capture_drafts',
        {
          'status': CaptureDraftStatus.saved.dbValue,
          'updated_at': now.toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [draft.id],
      );
      await txn.delete('detection_drafts',
          where: 'capture_draft_id = ?', whereArgs: [draft.id]);
    });

    // Photos attached to detections that were deselected/removed are no
    // longer needed.
    final kept = selected.map((d) => d.photoPath).toSet()
      ..add(draft.sourcePhotoPath);
    for (final d in draft.detections) {
      final ph = d.photoPath;
      if (ph != null && !kept.contains(ph)) await _photos.delete(ph);
    }
    return CommitResult(
        addedCount: added, mergedCount: merged, itemIds: ids, scanId: scanId);
  }

  @override
  Future<BarcodeProduct?> lookupBarcode(String code) async {
    final rows = await _db.query('barcode_products',
        where: 'barcode = ?', whereArgs: [code.trim()], limit: 1);
    return rows.isEmpty ? null : BarcodeProduct.fromRow(rows.first);
  }

  @override
  Future<List<ScanRecord>> getScanRecords() async {
    final rows = await _db.query('scan_history', orderBy: 'created_at DESC');
    return rows.map(ScanRecord.fromRow).toList();
  }

  @override
  Future<void> deleteScanRecord(String scanId) async {
    final rows = await _db.query('scan_history',
        where: 'id = ?', whereArgs: [scanId], limit: 1);
    if (rows.isEmpty) return;
    final photo = rows.first['photo_path'] as String?;
    await _db.delete('scan_history', where: 'id = ?', whereArgs: [scanId]);
    if (photo != null) {
      // Keep the file if a pantry item still uses it as its item photo.
      final used = await _db.query('pantry_items',
          columns: ['id'], where: 'photo_path = ?', whereArgs: [photo], limit: 1);
      if (used.isEmpty) await _photos.delete(photo);
    }
  }
}
