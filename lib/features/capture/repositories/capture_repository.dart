import '../../../core/enums/pantry_enums.dart';
import '../models/capture_models.dart';

class CommitResult {
  const CommitResult({
    required this.addedCount,
    required this.mergedCount,
    required this.itemIds,
    required this.scanId,
  });
  final int addedCount;
  final int mergedCount;
  final List<String> itemIds;
  final String? scanId;
  int get total => addedCount + mergedCount;
}

/// Capture drafts are persisted locally so an in-progress review survives
/// restarts. Nothing here touches pantry inventory except [commitDraft].
abstract interface class CaptureRepository {
  Future<CaptureDraft> createDraft({
    required CaptureMethod method,
    CaptureMode mode = CaptureMode.groceries,
    String? photoPath,
    String? barcode,
  });
  Future<CaptureDraft?> loadOpenDraft();
  Future<void> saveDraft(CaptureDraft draft);

  /// Cancels and deletes draft rows (and the draft photo when no saved scan
  /// record references it).
  Future<void> cancelDraft(String draftId);

  /// Atomically inserts all selected, confirmed detections as pantry items
  /// (or adds to reviewed merge targets), writes `item_added` transactions,
  /// the scan record and any barcode catalog entries. Throws if any selected
  /// detection is unresolved; on failure nothing is written.
  Future<CommitResult> commitDraft(CaptureDraft draft);

  Future<BarcodeProduct?> lookupBarcode(String code);
  Future<List<ScanRecord>> getScanRecords();

  /// Deletes the scan record and its photo. Confirmed inventory items remain.
  Future<void> deleteScanRecord(String scanId);
}
