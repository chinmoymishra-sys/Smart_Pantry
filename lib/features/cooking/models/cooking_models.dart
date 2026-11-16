import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/units.dart';

class CookingSession {
  const CookingSession({
    required this.id,
    required this.recipeId,
    required this.recipeName,
    required this.mealType,
    required this.status,
    required this.servings,
    required this.currentStep,
    required this.completedSteps,
    required this.startedAt,
    this.timerRemainingSeconds,
    this.timerRunning = false,
    this.pausedAt,
    this.completedAt,
    this.feedback,
    this.isFavoriteSaved = false,
    this.notes,
  });

  final String id;
  final String recipeId;
  final String recipeName;
  final MealType mealType;
  final CookingStatus status;
  final int servings;

  /// 1-based step currently shown.
  final int currentStep;
  final Set<int> completedSteps;
  final int? timerRemainingSeconds;
  final bool timerRunning;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final DateTime? completedAt;
  final CookingFeedback? feedback;
  final bool isFavoriteSaved;
  final String? notes;

  CookingSession copyWith({
    CookingStatus? status,
    int? servings,
    int? currentStep,
    Set<int>? completedSteps,
    int? timerRemainingSeconds,
    bool clearTimer = false,
    bool? timerRunning,
    DateTime? pausedAt,
    DateTime? completedAt,
    CookingFeedback? feedback,
    bool? isFavoriteSaved,
  }) =>
      CookingSession(
        id: id,
        recipeId: recipeId,
        recipeName: recipeName,
        mealType: mealType,
        status: status ?? this.status,
        servings: servings ?? this.servings,
        currentStep: currentStep ?? this.currentStep,
        completedSteps: completedSteps ?? this.completedSteps,
        timerRemainingSeconds: clearTimer
            ? null
            : (timerRemainingSeconds ?? this.timerRemainingSeconds),
        timerRunning: timerRunning ?? this.timerRunning,
        startedAt: startedAt,
        pausedAt: pausedAt ?? this.pausedAt,
        completedAt: completedAt ?? this.completedAt,
        feedback: feedback ?? this.feedback,
        isFavoriteSaved: isFavoriteSaved ?? this.isFavoriteSaved,
        notes: notes,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'recipe_id': recipeId,
        'recipe_name': recipeName,
        'meal_type': mealType.dbValue,
        'status': status.dbValue,
        'servings': servings,
        'current_step': currentStep,
        'completed_steps': (completedSteps.toList()..sort()).join(','),
        'timer_remaining_seconds': timerRemainingSeconds,
        'started_at': startedAt.toUtc().toIso8601String(),
        'paused_at': pausedAt?.toUtc().toIso8601String(),
        'completed_at': completedAt?.toUtc().toIso8601String(),
        'feedback': feedback?.dbValue,
        'is_favorite_saved': isFavoriteSaved ? 1 : 0,
        'notes': notes,
      };

  factory CookingSession.fromRow(Map<String, Object?> r) => CookingSession(
        id: r['id']! as String,
        recipeId: r['recipe_id']! as String,
        recipeName: r['recipe_name'] as String? ?? '',
        mealType: MealType.fromDb(r['meal_type'] as String?),
        status: CookingStatus.fromDb(r['status'] as String?),
        servings: r['servings'] as int? ?? 1,
        currentStep: r['current_step'] as int? ?? 1,
        completedSteps: (r['completed_steps'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toSet(),
        timerRemainingSeconds: r['timer_remaining_seconds'] as int?,
        startedAt: AppDates.fromDbTimestamp(r['started_at'] as String?) ??
            DateTime.now(),
        pausedAt: AppDates.fromDbTimestamp(r['paused_at'] as String?),
        completedAt: AppDates.fromDbTimestamp(r['completed_at'] as String?),
        feedback: CookingFeedback.fromDb(r['feedback'] as String?),
        isFavoriteSaved: (r['is_favorite_saved'] as int? ?? 0) == 1,
        notes: r['notes'] as String?,
      );
}

/// A proposed or confirmed ingredient deduction for a cooking session.
class CookingUsage {
  const CookingUsage({
    required this.id,
    required this.cookingSessionId,
    required this.ingredientName,
    required this.plannedQuantity,
    required this.plannedUnit,
    this.pantryItemId,
    this.actualQuantity,
    this.actualUnit,
    this.quantityBefore,
    this.quantityAfter,
    this.itemUnit,
    this.isSkipped = false,
    this.isConfirmed = false,
    this.packageNote,
  });

  final String id;
  final String cookingSessionId;
  final String? pantryItemId;
  final String ingredientName;
  final double plannedQuantity;
  final PantryUnit plannedUnit;

  /// User-edited amount actually used (in [actualUnit]).
  final double? actualQuantity;
  final PantryUnit? actualUnit;

  /// Pantry balance before/after, in the pantry item's own unit.
  final double? quantityBefore;
  final double? quantityAfter;
  final PantryUnit? itemUnit;
  final bool isSkipped;
  final bool isConfirmed;
  final String? packageNote;

  Map<String, Object?> toRow() => {
        'id': id,
        'cooking_session_id': cookingSessionId,
        'pantry_item_id': pantryItemId,
        'ingredient_name': ingredientName,
        'planned_quantity': plannedQuantity,
        'planned_unit': plannedUnit.dbValue,
        'actual_quantity': actualQuantity,
        'actual_unit': actualUnit?.dbValue,
        'quantity_before': quantityBefore,
        'quantity_after': quantityAfter,
        'item_unit': itemUnit?.dbValue,
        'is_skipped': isSkipped ? 1 : 0,
        'is_confirmed': isConfirmed ? 1 : 0,
      };

  factory CookingUsage.fromRow(Map<String, Object?> r) {
    final au = r['actual_unit'] as String?;
    final iu = r['item_unit'] as String?;
    return CookingUsage(
      id: r['id']! as String,
      cookingSessionId: r['cooking_session_id']! as String,
      pantryItemId: r['pantry_item_id'] as String?,
      ingredientName: r['ingredient_name'] as String? ?? '',
      plannedQuantity: (r['planned_quantity'] as num? ?? 0).toDouble(),
      plannedUnit: PantryUnit.fromDb(r['planned_unit'] as String?),
      actualQuantity: (r['actual_quantity'] as num?)?.toDouble(),
      actualUnit: au == null ? null : PantryUnit.fromDb(au),
      quantityBefore: (r['quantity_before'] as num?)?.toDouble(),
      quantityAfter: (r['quantity_after'] as num?)?.toDouble(),
      itemUnit: iu == null ? null : PantryUnit.fromDb(iu),
      isSkipped: (r['is_skipped'] as int? ?? 0) == 1,
      isConfirmed: (r['is_confirmed'] as int? ?? 0) == 1,
    );
  }
}

/// Editable deduction proposal shown on "What did you use?".
class DeductionProposal {
  const DeductionProposal({
    required this.ingredientName,
    required this.pantryItemId,
    required this.itemName,
    required this.before,
    required this.itemUnit,
    required this.used,
    required this.usedUnit,
    required this.plannedQuantity,
    required this.plannedUnit,
    this.packageNote,
    this.skipped = false,
  });

  final String ingredientName;
  final String pantryItemId;
  final String itemName;
  final double before;
  final PantryUnit itemUnit;
  final double used;
  final PantryUnit usedUnit;
  final double plannedQuantity;
  final PantryUnit plannedUnit;
  final String? packageNote;
  final bool skipped;

  /// Amount used converted into the item's unit, or null if incompatible.
  double? get usedInItemUnit => tryConvertQuantity(used, usedUnit, itemUnit);

  double? get after {
    final u = usedInItemUnit;
    if (u == null) return null;
    return before - u;
  }

  bool get exceedsStock => !skipped && (after ?? 0) < -1e-9;
  bool get hasUnitProblem => !skipped && usedInItemUnit == null;
  bool get isValid => skipped || (!exceedsStock && !hasUnitProblem && used >= 0);

  String get usedLabel {
    final base = formatQuantity(used, usedUnit);
    return packageNote == null ? base : '$base ($packageNote)';
  }

  /// [clearPackageNote] drops the "(240 g drained)" hint once the user edits
  /// the amount, since it described the originally proposed quantity.
  DeductionProposal copyWith({
    double? used,
    PantryUnit? usedUnit,
    bool? skipped,
    bool clearPackageNote = false,
  }) =>
      DeductionProposal(
        ingredientName: ingredientName,
        pantryItemId: pantryItemId,
        itemName: itemName,
        before: before,
        itemUnit: itemUnit,
        used: used ?? this.used,
        usedUnit: usedUnit ?? this.usedUnit,
        plannedQuantity: plannedQuantity,
        plannedUnit: plannedUnit,
        packageNote: clearPackageNote ? null : packageNote,
        skipped: skipped ?? this.skipped,
      );
}
