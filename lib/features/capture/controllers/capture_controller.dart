import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/pantry_enums.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';
import '../../../providers/repository_providers.dart';
import '../../history/controllers/history_controller.dart';
import '../../inventory/controllers/inventory_controller.dart';
import '../models/capture_models.dart';
import '../repositories/capture_repository.dart';

/// Coordinates the capture → review → confirm flow. The draft is persisted
/// after every change so it survives restarts, but it never changes pantry
/// inventory until [commit] succeeds.
class CaptureController extends AsyncNotifier<CaptureDraft?> {
  static const _uuid = Uuid();
  bool _committing = false;

  CaptureRepository get _repo => ref.read(captureRepositoryProvider);

  @override
  Future<CaptureDraft?> build() => _repo.loadOpenDraft();

  CaptureDraft? get draft => state.value;

  Future<CaptureDraft> start({
    required CaptureMethod method,
    CaptureMode mode = CaptureMode.groceries,
    String? sourcePhotoPath,
    String? barcode,
  }) async {
    String? stored;
    if (sourcePhotoPath != null) {
      stored = await ref.read(photoStorageProvider).importPhoto(sourcePhotoPath);
    }
    final d = await _repo.createDraft(
      method: method,
      mode: mode,
      photoPath: stored,
      barcode: barcode,
    );
    state = AsyncData(d);
    return d;
  }

  /// Returns the open draft, creating a manual one if none exists.
  Future<CaptureDraft> ensureDraft({
    CaptureMethod method = CaptureMethod.manual,
  }) async {
    final d = draft;
    if (d != null && d.status == CaptureDraftStatus.open) return d;
    return start(method: method);
  }

  Future<void> _persist(CaptureDraft d) async {
    state = AsyncData(d);
    await _repo.saveDraft(d);
  }

  Future<void> setMode(CaptureMode mode) async {
    final d = draft;
    if (d != null) await _persist(d.copyWith(mode: mode));
  }

  Future<void> replaceSourcePhoto(String? path) async {
    final d = draft;
    if (d == null) return;
    final old = d.sourcePhotoPath;
    String? stored;
    if (path != null) {
      stored = await ref.read(photoStorageProvider).importPhoto(path);
    }
    await _persist(d.copyWith(sourcePhotoPath: stored, clearPhoto: stored == null));
    if (old != null && old != stored) {
      await ref.read(photoStorageProvider).delete(old);
    }
  }

  DetectionDraft newDetection({
    required String captureDraftId,
    String name = '',
    FoodCategory category = FoodCategory.vegetable,
    double? quantity,
    PantryUnit unit = PantryUnit.pieces,
    QuantitySource source = QuantitySource.userEntered,
    FoodState foodState = FoodState.raw,
    StorageLocation storage = StorageLocation.fridge,
    String? barcode,
    double? packageContentQuantity,
    PantryUnit? packageContentUnit,
  }) =>
      DetectionDraft(
        id: _uuid.v4(),
        captureDraftId: captureDraftId,
        name: name,
        category: category,
        quantity: quantity,
        unit: unit,
        quantitySource: source,
        foodState: foodState,
        storage: storage,
        dateAdded: AppDates.today(),
        barcode: barcode,
        packageContentQuantity: packageContentQuantity,
        packageContentUnit: packageContentUnit,
        createdAt: DateTime.now(),
        sortOrder: (draft?.detections.length ?? 0),
      );

  DetectionDraft? detection(String id) {
    for (final d in draft?.detections ?? const <DetectionDraft>[]) {
      if (d.id == id) return d;
    }
    return null;
  }

  void _validate(DetectionDraft d) {
    if (d.name.trim().isEmpty) {
      throw ValidationException('Enter the item name.');
    }
    if (d.quantity == null || d.quantity! <= 0) {
      throw ValidationException('Enter a quantity above zero.');
    }
    if (d.lowStockThreshold != null && d.lowStockThreshold! <= 0) {
      throw ValidationException('Low-stock threshold must be above zero.');
    }
  }

  /// Adds or replaces a detection in the draft (validated). A replaced item
  /// photo that nothing else references is deleted from app storage.
  Future<void> upsertDetection(DetectionDraft det) async {
    _validate(det);
    final d = draft;
    if (d == null) throw StateError('No capture draft is open.');
    final list = [...d.detections];
    final idx = list.indexWhere((x) => x.id == det.id);
    final oldPhoto = idx >= 0 ? list[idx].photoPath : null;
    if (idx >= 0) {
      list[idx] = det;
    } else {
      list.add(det);
    }
    await _persist(d.copyWith(detections: list));
    if (oldPhoto != null && oldPhoto != det.photoPath) {
      await discardPhoto(oldPhoto);
    }
  }

  /// Copies a picked/captured image into app storage and returns the stored
  /// path. Attach it to a detection with [upsertDetection].
  Future<String> importPhoto(String path) =>
      ref.read(photoStorageProvider).importPhoto(path);

  /// Deletes an imported photo unless the open draft still references it
  /// (as the source photo or any detection's photo).
  Future<void> discardPhoto(String path) async {
    final d = draft;
    if (d != null &&
        (d.sourcePhotoPath == path ||
            d.detections.any((x) => x.photoPath == path))) {
      return;
    }
    await ref.read(photoStorageProvider).delete(path);
  }

  /// Adds recognition suggestions to the draft as *unconfirmed* detections.
  /// Quantities are kept only as visual estimates (or left empty); the user
  /// must confirm identity and supply a quantity before saving is possible.
  Future<int> addSuggestedDetections(
    List<({String name, FoodCategory category, double? quantity, PantryUnit unit})>
        suggestions,
  ) async {
    final d = draft;
    if (d == null) throw StateError('No capture draft is open.');
    final list = [...d.detections];
    for (final s in suggestions) {
      if (s.name.trim().isEmpty) continue;
      list.add(DetectionDraft(
        id: _uuid.v4(),
        captureDraftId: d.id,
        suggestedName: s.name.trim(),
        name: s.name.trim(),
        category: s.category,
        quantity: (s.quantity != null && s.quantity! > 0) ? s.quantity : null,
        unit: s.unit,
        quantitySource: QuantitySource.visualEstimate,
        foodState: FoodState.raw,
        storage: StorageLocation.fridge,
        isIdentityConfirmed: false,
        dateAdded: AppDates.today(),
        createdAt: DateTime.now(),
        sortOrder: list.length,
      ));
    }
    await _persist(d.copyWith(detections: list));
    return list.length - d.detections.length;
  }

  Future<void> removeDetection(String id) async {
    final d = draft;
    if (d == null) return;
    final removed = detection(id);
    await _persist(d.copyWith(
        detections: d.detections.where((x) => x.id != id).toList()));
    final ph = removed?.photoPath;
    if (ph != null) await discardPhoto(ph);
  }

  Future<void> toggleSelected(String id) async {
    final det = detection(id);
    if (det == null) return;
    final d = draft!;
    await _persist(d.copyWith(
      detections: [
        for (final x in d.detections)
          x.id == id ? x.copyWith(isSelected: !x.isSelected) : x,
      ],
    ));
  }

  /// Merge previewed by the user: keeps the first record with the reviewed
  /// name and combined quantity. Units must be compatible; dates/storage
  /// conflicts must be resolved by the caller (passed explicitly).
  Future<void> mergeDetections({
    required List<String> ids,
    required String mergedName,
    required PantryUnit unit,
  }) async {
    final d = draft;
    if (d == null || ids.length < 2) {
      throw ValidationException('Choose at least two detections to merge.');
    }
    final parts = ids.map(detection).whereType<DetectionDraft>().toList();
    var total = 0.0;
    for (final p in parts) {
      if (!p.hasQuantity) {
        throw ValidationException('Enter a quantity for ${p.displayName} first.');
      }
      final c = tryConvertQuantity(p.quantity!, p.unit, unit);
      if (c == null) {
        throw ValidationException(
            'Units differ (${p.unit.dbValue} vs ${unit.dbValue}). Resolve them before merging.');
      }
      total += c;
    }
    final expiries = parts.map((p) => p.expiryDate).toSet();
    if (expiries.length > 1) {
      throw ValidationException(
          'These detections have different dates. Edit them to match before merging.');
    }
    final storages = parts.map((p) => p.storage).toSet();
    final states = parts.map((p) => p.foodState).toSet();
    if (storages.length > 1 || states.length > 1) {
      throw ValidationException(
          'Storage or food state differs. Edit them to match before merging.');
    }
    final first = parts.first;
    final anyEstimate =
        parts.any((p) => p.quantitySource == QuantitySource.visualEstimate);
    final merged = first.copyWith(
      name: mergedName.trim(),
      quantity: total,
      unit: unit,
      quantitySource:
          anyEstimate ? QuantitySource.visualEstimate : first.quantitySource,
      isIdentityConfirmed: true,
      notes: [
        if (first.notes?.isNotEmpty ?? false) first.notes,
        'Merged from ${parts.map((p) => p.name).join(' + ')}',
      ].join(' · '),
    );
    final rest = ids.skip(1).toSet();
    await _persist(d.copyWith(detections: [
      for (final x in d.detections)
        if (x.id == first.id) merged else if (!rest.contains(x.id)) x,
    ]));
  }

  /// Replaces a mixed detection with user-entered parts. Quantities are
  /// never divided automatically; each part must carry its own quantity.
  Future<void> splitDetection(String sourceId, List<DetectionDraft> parts) async {
    final d = draft;
    final src = detection(sourceId);
    if (d == null || src == null) return;
    if (parts.length < 2) {
      throw ValidationException('Add at least two items to split into.');
    }
    for (final p in parts) {
      _validate(p);
    }
    final out = <DetectionDraft>[];
    for (final x in d.detections) {
      if (x.id == sourceId) {
        out.addAll(parts);
      } else {
        out.add(x);
      }
    }
    await _persist(d.copyWith(detections: out));
    final ph = src.photoPath;
    if (ph != null) await discardPhoto(ph);
  }

  Future<BarcodeProduct?> lookupBarcode(String code) {
    final c = code.trim();
    if (!RegExp(r'^[0-9A-Za-z\-]{4,64}$').hasMatch(c)) {
      throw ValidationException('Enter the barcode digits shown on the package.');
    }
    return _repo.lookupBarcode(c);
  }

  /// Saves selected, confirmed detections in one transaction. Guarded
  /// against duplicate submissions.
  Future<CommitResult> commit() async {
    final d = draft;
    if (d == null) throw StateError('No capture draft is open.');
    if (_committing) throw StateError('Already saving.');
    _committing = true;
    try {
      final result = await _repo.commitDraft(d);
      state = const AsyncData(null);
      await ref.read(inventoryProvider.notifier).refresh();
      ref.invalidate(scanRecordsProvider);
      return result;
    } finally {
      _committing = false;
    }
  }

  Future<void> cancel() async {
    final d = draft;
    if (d != null) await _repo.cancelDraft(d.id);
    state = const AsyncData(null);
  }
}

final captureControllerProvider =
    AsyncNotifierProvider<CaptureController, CaptureDraft?>(
        CaptureController.new);

/// Result of the most recent save, shown on the success screen.
class LastCommitController extends Notifier<CommitResult?> {
  @override
  CommitResult? build() => null;
  void set(CommitResult? r) => state = r;
}

final lastCommitProvider =
    NotifierProvider<LastCommitController, CommitResult?>(
        LastCommitController.new);
