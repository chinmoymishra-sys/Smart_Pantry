import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';

/// One reviewable item inside a capture draft. Drafts never affect inventory
/// counts until the user explicitly confirms and saves.
class DetectionDraft {
  const DetectionDraft({
    required this.id,
    required this.captureDraftId,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.quantitySource,
    required this.foodState,
    required this.storage,
    required this.createdAt,
    this.suggestedName,
    this.customLocationName,
    this.isIdentityConfirmed = true,
    this.isSelected = true,
    this.condition = Condition.notAssessed,
    this.freshness = Condition.notAssessed,
    this.dateAdded,
    this.purchaseDate,
    this.expiryDate,
    this.dateType = DateType.useBy,
    this.openedDate,
    this.lowStockThreshold,
    this.notes,
    this.photoPath,
    this.barcode,
    this.packageContentQuantity,
    this.packageContentUnit,
    this.mergeTargetItemId,
    this.sortOrder = 0,
  });

  final String id;
  final String captureDraftId;

  /// What a recognition service suggested (null for user-entered items).
  final String? suggestedName;

  /// Current name (user-confirmed or user-entered).
  final String name;
  final FoodCategory category;

  /// null when the user hasn't supplied a quantity yet.
  final double? quantity;
  final PantryUnit unit;
  final QuantitySource quantitySource;
  final FoodState foodState;
  final StorageLocation storage;
  final String? customLocationName;
  final bool isIdentityConfirmed;
  final bool isSelected;
  final Condition condition;
  final Condition freshness;
  final DateTime? dateAdded;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final DateType dateType;
  final DateTime? openedDate;
  final double? lowStockThreshold;
  final String? notes;
  final String? photoPath;
  final String? barcode;
  final double? packageContentQuantity;
  final PantryUnit? packageContentUnit;

  /// When set, saving adds this quantity to an existing pantry item (a merge
  /// the user reviewed) instead of creating a new record.
  final String? mergeTargetItemId;
  final int sortOrder;
  final DateTime createdAt;

  bool get hasQuantity => quantity != null && quantity! > 0;

  /// Ready to save: identity confirmed and a positive quantity present.
  bool get isReadyToSave => isIdentityConfirmed && hasQuantity;

  String get displayName => isIdentityConfirmed ? name : '$name?';

  String get quantityLine {
    if (!hasQuantity) return 'Quantity needed';
    final q = formatQuantity(quantity!, unit);
    return quantitySource == QuantitySource.visualEstimate
        ? 'About $q · ${quantitySource.label}'
        : '$q · ${quantitySource.label}';
  }

  String get storageLabel => storage == StorageLocation.custom &&
          (customLocationName?.trim().isNotEmpty ?? false)
      ? customLocationName!.trim()
      : storage.label;

  String get dateLine {
    if (expiryDate == null) return 'Expiry not set';
    return '${dateType.label} ${AppDates.short(expiryDate!)} · entered by you';
  }

  DetectionDraft copyWith({
    String? name,
    FoodCategory? category,
    double? quantity,
    bool clearQuantity = false,
    PantryUnit? unit,
    QuantitySource? quantitySource,
    FoodState? foodState,
    StorageLocation? storage,
    String? customLocationName,
    bool? isIdentityConfirmed,
    bool? isSelected,
    Condition? condition,
    Condition? freshness,
    DateTime? dateAdded,
    DateTime? purchaseDate,
    bool clearPurchaseDate = false,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    DateType? dateType,
    DateTime? openedDate,
    bool clearOpenedDate = false,
    double? lowStockThreshold,
    bool clearLowStock = false,
    String? notes,
    String? photoPath,
    bool clearPhoto = false,
    String? mergeTargetItemId,
    bool clearMergeTarget = false,
    int? sortOrder,
  }) =>
      DetectionDraft(
        id: id,
        captureDraftId: captureDraftId,
        suggestedName: suggestedName,
        name: name ?? this.name,
        category: category ?? this.category,
        quantity: clearQuantity ? null : (quantity ?? this.quantity),
        unit: unit ?? this.unit,
        quantitySource: quantitySource ?? this.quantitySource,
        foodState: foodState ?? this.foodState,
        storage: storage ?? this.storage,
        customLocationName: customLocationName ?? this.customLocationName,
        isIdentityConfirmed: isIdentityConfirmed ?? this.isIdentityConfirmed,
        isSelected: isSelected ?? this.isSelected,
        condition: condition ?? this.condition,
        freshness: freshness ?? this.freshness,
        dateAdded: dateAdded ?? this.dateAdded,
        purchaseDate:
            clearPurchaseDate ? null : (purchaseDate ?? this.purchaseDate),
        expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
        dateType: dateType ?? this.dateType,
        openedDate: clearOpenedDate ? null : (openedDate ?? this.openedDate),
        lowStockThreshold: clearLowStock
            ? null
            : (lowStockThreshold ?? this.lowStockThreshold),
        notes: notes ?? this.notes,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        barcode: barcode,
        packageContentQuantity: packageContentQuantity,
        packageContentUnit: packageContentUnit,
        mergeTargetItemId: clearMergeTarget
            ? null
            : (mergeTargetItemId ?? this.mergeTargetItemId),
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'capture_draft_id': captureDraftId,
        'suggested_name': suggestedName,
        'confirmed_name': name,
        'category': category.dbValue,
        'estimated_quantity': quantity,
        'estimated_unit': unit.dbValue,
        'quantity_source': quantitySource.dbValue,
        'food_state': foodState.dbValue,
        'storage_location': storage.dbValue,
        'custom_location_name': customLocationName,
        'is_identity_confirmed': isIdentityConfirmed ? 1 : 0,
        'is_selected': isSelected ? 1 : 0,
        'is_removed': 0,
        'quality_condition': condition.dbValue,
        'freshness': freshness.dbValue,
        'date_added': AppDates.toDbDate(dateAdded),
        'purchase_date': AppDates.toDbDate(purchaseDate),
        'expiry_date': AppDates.toDbDate(expiryDate),
        'date_type': dateType.dbValue,
        'opened_prepared_date': AppDates.toDbDate(openedDate),
        'low_stock_threshold': lowStockThreshold,
        'notes': notes,
        'photo_path': photoPath,
        'barcode': barcode,
        'package_content_quantity': packageContentQuantity,
        'package_content_unit': packageContentUnit?.dbValue,
        'merge_target_item_id': mergeTargetItemId,
        'sort_order': sortOrder,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory DetectionDraft.fromRow(Map<String, Object?> r) {
    final pkgUnit = r['package_content_unit'] as String?;
    return DetectionDraft(
      id: r['id']! as String,
      captureDraftId: r['capture_draft_id']! as String,
      suggestedName: r['suggested_name'] as String?,
      name: r['confirmed_name'] as String? ?? '',
      category: FoodCategory.fromDb(r['category'] as String?),
      quantity: (r['estimated_quantity'] as num?)?.toDouble(),
      unit: PantryUnit.fromDb(r['estimated_unit'] as String?),
      quantitySource: QuantitySource.fromDb(r['quantity_source'] as String?),
      foodState: FoodState.fromDb(r['food_state'] as String?),
      storage: StorageLocation.fromDb(r['storage_location'] as String?),
      customLocationName: r['custom_location_name'] as String?,
      isIdentityConfirmed: (r['is_identity_confirmed'] as int? ?? 1) == 1,
      isSelected: (r['is_selected'] as int? ?? 1) == 1,
      condition: Condition.fromDb(r['quality_condition'] as String?),
      freshness: Condition.fromDb(r['freshness'] as String?),
      dateAdded: AppDates.fromDbDate(r['date_added'] as String?),
      purchaseDate: AppDates.fromDbDate(r['purchase_date'] as String?),
      expiryDate: AppDates.fromDbDate(r['expiry_date'] as String?),
      dateType: DateType.fromDb(r['date_type'] as String?),
      openedDate: AppDates.fromDbDate(r['opened_prepared_date'] as String?),
      lowStockThreshold: (r['low_stock_threshold'] as num?)?.toDouble(),
      notes: r['notes'] as String?,
      photoPath: r['photo_path'] as String?,
      barcode: r['barcode'] as String?,
      packageContentQuantity:
          (r['package_content_quantity'] as num?)?.toDouble(),
      packageContentUnit: pkgUnit == null ? null : PantryUnit.fromDb(pkgUnit),
      mergeTargetItemId: r['merge_target_item_id'] as String?,
      sortOrder: r['sort_order'] as int? ?? 0,
      createdAt:
          AppDates.fromDbTimestamp(r['created_at'] as String?) ?? DateTime.now(),
    );
  }
}

enum CaptureDraftStatus {
  open('open'),
  saved('saved'),
  cancelled('cancelled');

  const CaptureDraftStatus(this.dbValue);
  final String dbValue;
  static CaptureDraftStatus fromDb(String? raw) => values.firstWhere(
        (v) => v.dbValue == raw,
        orElse: () => CaptureDraftStatus.open,
      );
}

class CaptureDraft {
  const CaptureDraft({
    required this.id,
    required this.method,
    required this.mode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sourcePhotoPath,
    this.barcodeValue,
    this.detections = const [],
  });

  final String id;
  final CaptureMethod method;
  final CaptureMode mode;
  final String? sourcePhotoPath;
  final String? barcodeValue;
  final CaptureDraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DetectionDraft> detections;

  List<DetectionDraft> get selected =>
      detections.where((d) => d.isSelected).toList();
  List<DetectionDraft> get unresolved =>
      selected.where((d) => !d.isReadyToSave).toList();

  /// Save is available only when ≥1 item is selected and every selected item
  /// has a confirmed identity and a quantity.
  bool get canSave => selected.isNotEmpty && unresolved.isEmpty;

  CaptureDraft copyWith({
    String? sourcePhotoPath,
    bool clearPhoto = false,
    CaptureMode? mode,
    CaptureDraftStatus? status,
    List<DetectionDraft>? detections,
    DateTime? updatedAt,
  }) =>
      CaptureDraft(
        id: id,
        method: method,
        mode: mode ?? this.mode,
        sourcePhotoPath:
            clearPhoto ? null : (sourcePhotoPath ?? this.sourcePhotoPath),
        barcodeValue: barcodeValue,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        detections: detections ?? this.detections,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'capture_method': method.dbValue,
        'capture_mode': mode.dbValue,
        'source_photo_path': sourcePhotoPath,
        'barcode_value': barcodeValue,
        'status': status.dbValue,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory CaptureDraft.fromRow(
    Map<String, Object?> r,
    List<DetectionDraft> detections,
  ) =>
      CaptureDraft(
        id: r['id']! as String,
        method: CaptureMethod.fromDb(r['capture_method'] as String?),
        mode: CaptureMode.fromDb(r['capture_mode'] as String?),
        sourcePhotoPath: r['source_photo_path'] as String?,
        barcodeValue: r['barcode_value'] as String?,
        status: CaptureDraftStatus.fromDb(r['status'] as String?),
        createdAt: AppDates.fromDbTimestamp(r['created_at'] as String?) ??
            DateTime.now(),
        updatedAt: AppDates.fromDbTimestamp(r['updated_at'] as String?) ??
            DateTime.now(),
        detections: detections,
      );
}

/// A product the household recorded against a barcode. This local catalog
/// is built only from the user's own confirmed entries — never fabricated.
class BarcodeProduct {
  const BarcodeProduct({
    required this.barcode,
    required this.name,
    required this.category,
    required this.foodState,
    required this.unit,
    required this.updatedAt,
    this.brand,
    this.packageSizeQuantity,
    this.packageSizeUnit,
  });

  final String barcode;
  final String name;
  final String? brand;
  final FoodCategory category;
  final FoodState foodState;
  final PantryUnit unit;
  final double? packageSizeQuantity;
  final PantryUnit? packageSizeUnit;
  final DateTime updatedAt;

  Map<String, Object?> toRow() => {
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'category': category.dbValue,
        'food_state': foodState.dbValue,
        'unit': unit.dbValue,
        'package_size_quantity': packageSizeQuantity,
        'package_size_unit': packageSizeUnit?.dbValue,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory BarcodeProduct.fromRow(Map<String, Object?> r) {
    final psu = r['package_size_unit'] as String?;
    return BarcodeProduct(
      barcode: r['barcode']! as String,
      name: r['name']! as String,
      brand: r['brand'] as String?,
      category: FoodCategory.fromDb(r['category'] as String?),
      foodState: FoodState.fromDb(r['food_state'] as String?),
      unit: PantryUnit.fromDb(r['unit'] as String?),
      packageSizeQuantity: (r['package_size_quantity'] as num?)?.toDouble(),
      packageSizeUnit: psu == null ? null : PantryUnit.fromDb(psu),
      updatedAt:
          AppDates.fromDbTimestamp(r['updated_at'] as String?) ?? DateTime.now(),
    );
  }
}

class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.captureDraftId,
    required this.method,
    required this.status,
    required this.confirmedItemCount,
    required this.itemNames,
    required this.createdAt,
    this.photoPath,
  });

  final String id;
  final String captureDraftId;
  final CaptureMethod method;
  final String? photoPath;
  final String status;
  final int confirmedItemCount;
  final List<String> itemNames;
  final DateTime createdAt;

  factory ScanRecord.fromRow(Map<String, Object?> r) => ScanRecord(
        id: r['id']! as String,
        captureDraftId: r['capture_draft_id'] as String? ?? '',
        method: CaptureMethod.fromDb(r['capture_method'] as String?),
        photoPath: r['photo_path'] as String?,
        status: r['status'] as String? ?? 'saved',
        confirmedItemCount: r['confirmed_item_count'] as int? ?? 0,
        itemNames: (r['item_names'] as String? ?? '')
            .split('\n')
            .where((s) => s.isNotEmpty)
            .toList(),
        createdAt: AppDates.fromDbTimestamp(r['created_at'] as String?) ??
            DateTime.now(),
      );
}
