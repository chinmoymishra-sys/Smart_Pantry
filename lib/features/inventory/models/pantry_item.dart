import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';

/// A confirmed food record in the household inventory.
///
/// Uncertain detections are never PantryItems; they live in capture drafts
/// until the user confirms them.
class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.foodState,
    required this.storage,
    required this.dateAdded,
    required this.createdAt,
    required this.updatedAt,
    this.customLocationName,
    this.condition = Condition.notAssessed,
    this.freshness = Condition.notAssessed,
    this.purchaseDate,
    this.expiryDate,
    this.dateType = DateType.useBy,
    this.openedDate,
    this.lowStockThreshold,
    this.lowStockUnit,
    this.notes,
    this.photoPath,
    this.sourceType = SourceType.manual,
    this.quantitySource = QuantitySource.userEntered,
    this.packageContentQuantity,
    this.packageContentUnit,
    this.barcode,
    this.isUnavailable = false,
  });

  final String id;
  final String name;
  final FoodCategory category;
  final double quantity;
  final PantryUnit unit;
  final FoodState foodState;
  final StorageLocation storage;
  final String? customLocationName;
  final Condition condition;
  final Condition freshness;
  final DateTime dateAdded;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final DateType dateType;
  final DateTime? openedDate;
  final double? lowStockThreshold;
  final PantryUnit? lowStockUnit;
  final String? notes;
  final String? photoPath;
  final SourceType sourceType;
  final QuantitySource quantitySource;

  /// Optional explicit package content, e.g. 240 g drained per tin.
  final double? packageContentQuantity;
  final PantryUnit? packageContentUnit;
  final String? barcode;
  final bool isUnavailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String normalize(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  String get normalizedName => normalize(name);

  String get storageLabel => storage == StorageLocation.custom
      ? (customLocationName?.trim().isNotEmpty == true
          ? customLocationName!.trim()
          : StorageLocation.custom.label)
      : storage.label;

  bool get isOut => quantity <= 0;

  /// Excluded from meal matching: out of stock or marked unavailable.
  bool get isUsable => !isOut && !isUnavailable;

  bool get isLowStock {
    final t = lowStockThreshold;
    if (t == null || isOut) return false;
    final threshold = tryConvertQuantity(t, lowStockUnit ?? unit, unit);
    if (threshold == null) return false;
    return quantity < threshold;
  }

  int? get daysUntilExpiry =>
      expiryDate == null ? null : AppDates.daysUntil(expiryDate!);

  bool get isUseSoon {
    final d = daysUntilExpiry;
    return d != null && d >= 0 && d <= AppDates.useSoonDays && !isOut;
  }

  bool get isPastDate {
    final d = daysUntilExpiry;
    return d != null && d < 0;
  }

  String get quantityLabel => formatQuantity(quantity, unit);
  String get quantityShortLabel => formatQuantity(quantity, unit, short: true);

  String? get packageContentLabel {
    if (packageContentQuantity == null || packageContentUnit == null) {
      return null;
    }
    return '${formatQuantity(packageContentQuantity!, packageContentUnit!)} '
        'per ${_singularUnit(unit)}';
  }

  static String _singularUnit(PantryUnit u) =>
      formatQuantity(1, u).split(' ').last;

  /// e.g. "Use by 8 Nov · your date" / "No date recorded".
  String get dateSummary {
    if (expiryDate == null) return 'No date recorded';
    return '${dateType.label} ${AppDates.short(expiryDate!)} · your date';
  }

  PantryItem copyWith({
    String? name,
    FoodCategory? category,
    double? quantity,
    PantryUnit? unit,
    FoodState? foodState,
    StorageLocation? storage,
    String? customLocationName,
    bool clearCustomLocation = false,
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
    PantryUnit? lowStockUnit,
    String? notes,
    bool clearNotes = false,
    String? photoPath,
    bool clearPhoto = false,
    QuantitySource? quantitySource,
    double? packageContentQuantity,
    PantryUnit? packageContentUnit,
    bool clearPackageContent = false,
    bool? isUnavailable,
    DateTime? updatedAt,
  }) {
    return PantryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      foodState: foodState ?? this.foodState,
      storage: storage ?? this.storage,
      customLocationName: clearCustomLocation
          ? null
          : (customLocationName ?? this.customLocationName),
      condition: condition ?? this.condition,
      freshness: freshness ?? this.freshness,
      dateAdded: dateAdded ?? this.dateAdded,
      purchaseDate:
          clearPurchaseDate ? null : (purchaseDate ?? this.purchaseDate),
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      dateType: dateType ?? this.dateType,
      openedDate: clearOpenedDate ? null : (openedDate ?? this.openedDate),
      lowStockThreshold:
          clearLowStock ? null : (lowStockThreshold ?? this.lowStockThreshold),
      lowStockUnit: clearLowStock ? null : (lowStockUnit ?? this.lowStockUnit),
      notes: clearNotes ? null : (notes ?? this.notes),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      sourceType: sourceType,
      quantitySource: quantitySource ?? this.quantitySource,
      packageContentQuantity: clearPackageContent
          ? null
          : (packageContentQuantity ?? this.packageContentQuantity),
      packageContentUnit: clearPackageContent
          ? null
          : (packageContentUnit ?? this.packageContentUnit),
      barcode: barcode,
      isUnavailable: isUnavailable ?? this.isUnavailable,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name.trim(),
        'normalized_name': normalizedName,
        'category': category.dbValue,
        'quantity': quantity,
        'unit': unit.dbValue,
        'food_state': foodState.dbValue,
        'storage_location': storage.dbValue,
        'custom_location_name': customLocationName,
        'quality_condition': condition.dbValue,
        'freshness': freshness.dbValue,
        'date_added': AppDates.toDbDate(dateAdded),
        'purchase_date': AppDates.toDbDate(purchaseDate),
        'expiry_date': AppDates.toDbDate(expiryDate),
        'date_type': dateType.dbValue,
        'opened_prepared_date': AppDates.toDbDate(openedDate),
        'low_stock_threshold': lowStockThreshold,
        'low_stock_unit': lowStockUnit?.dbValue,
        'notes': notes,
        'photo_path': photoPath,
        'source_type': sourceType.dbValue,
        'quantity_source': quantitySource.dbValue,
        'package_content_quantity': packageContentQuantity,
        'package_content_unit': packageContentUnit?.dbValue,
        'barcode': barcode,
        'identity_confirmed': 1,
        'is_unavailable': isUnavailable ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory PantryItem.fromRow(Map<String, Object?> r) {
    final lowUnit = r['low_stock_unit'] as String?;
    final pkgUnit = r['package_content_unit'] as String?;
    return PantryItem(
      id: r['id']! as String,
      name: r['name']! as String,
      category: FoodCategory.fromDb(r['category'] as String?),
      quantity: (r['quantity']! as num).toDouble(),
      unit: PantryUnit.fromDb(r['unit'] as String?),
      foodState: FoodState.fromDb(r['food_state'] as String?),
      storage: StorageLocation.fromDb(r['storage_location'] as String?),
      customLocationName: r['custom_location_name'] as String?,
      condition: Condition.fromDb(r['quality_condition'] as String?),
      freshness: Condition.fromDb(r['freshness'] as String?),
      dateAdded: AppDates.fromDbDate(r['date_added'] as String?) ??
          AppDates.today(),
      purchaseDate: AppDates.fromDbDate(r['purchase_date'] as String?),
      expiryDate: AppDates.fromDbDate(r['expiry_date'] as String?),
      dateType: DateType.fromDb(r['date_type'] as String?),
      openedDate: AppDates.fromDbDate(r['opened_prepared_date'] as String?),
      lowStockThreshold: (r['low_stock_threshold'] as num?)?.toDouble(),
      lowStockUnit: lowUnit == null ? null : PantryUnit.fromDb(lowUnit),
      notes: r['notes'] as String?,
      photoPath: r['photo_path'] as String?,
      sourceType: SourceType.fromDb(r['source_type'] as String?),
      quantitySource: QuantitySource.fromDb(r['quantity_source'] as String?),
      packageContentQuantity:
          (r['package_content_quantity'] as num?)?.toDouble(),
      packageContentUnit: pkgUnit == null ? null : PantryUnit.fromDb(pkgUnit),
      barcode: r['barcode'] as String?,
      isUnavailable: (r['is_unavailable'] as int? ?? 0) == 1,
      createdAt:
          AppDates.fromDbTimestamp(r['created_at'] as String?) ?? DateTime.now(),
      updatedAt:
          AppDates.fromDbTimestamp(r['updated_at'] as String?) ?? DateTime.now(),
    );
  }
}
