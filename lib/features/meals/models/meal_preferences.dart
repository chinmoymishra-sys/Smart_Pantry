import 'dart:convert';

import '../../../core/enums/pantry_enums.dart';

enum PantryMatchMode {
  any('any', 'Any match'),
  availableOnly('available_only', 'Available only'),
  fewestMissing('fewest_missing', 'Fewest missing');

  const PantryMatchMode(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static PantryMatchMode fromDb(String? raw) => values.firstWhere(
        (v) => v.dbValue == raw,
        orElse: () => PantryMatchMode.any,
      );
}

/// Meal discovery preferences. Dietary choices are *preferences*, never an
/// allergy-safety guarantee.
class MealPreferences {
  const MealPreferences({
    this.mealType,
    this.maxMinutes,
    this.difficulty,
    this.matchMode = PantryMatchMode.any,
    this.useSoonFirst = true,
    this.dietaryPreference,
    this.excludedIngredients = const [],
    this.cuisine,
  });

  /// null = any meal.
  final MealType? mealType;

  /// null = any time; otherwise 15 / 30 / 60.
  final int? maxMinutes;
  final Difficulty? difficulty;
  final PantryMatchMode matchMode;
  final bool useSoonFirst;

  /// null = no preference; e.g. "Vegetarian", "Vegan", "Dairy-free".
  final String? dietaryPreference;
  final List<String> excludedIngredients;

  /// null = any cuisine.
  final String? cuisine;

  static const dietaryOptions = ['Vegetarian', 'Vegan', 'Dairy-free'];
  static const cuisineOptions = [
    'Indian-inspired',
    'Mediterranean',
    'One-pot',
    'Comfort food',
  ];
  static const timeOptions = [15, 30, 60];

  bool get hasActiveFilters =>
      mealType != null ||
      maxMinutes != null ||
      difficulty != null ||
      matchMode != PantryMatchMode.any ||
      dietaryPreference != null ||
      excludedIngredients.isNotEmpty ||
      cuisine != null;

  MealPreferences copyWith({
    MealType? mealType,
    bool clearMealType = false,
    int? maxMinutes,
    bool clearMaxMinutes = false,
    Difficulty? difficulty,
    bool clearDifficulty = false,
    PantryMatchMode? matchMode,
    bool? useSoonFirst,
    String? dietaryPreference,
    bool clearDietary = false,
    List<String>? excludedIngredients,
    String? cuisine,
    bool clearCuisine = false,
  }) =>
      MealPreferences(
        mealType: clearMealType ? null : (mealType ?? this.mealType),
        maxMinutes: clearMaxMinutes ? null : (maxMinutes ?? this.maxMinutes),
        difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
        matchMode: matchMode ?? this.matchMode,
        useSoonFirst: useSoonFirst ?? this.useSoonFirst,
        dietaryPreference:
            clearDietary ? null : (dietaryPreference ?? this.dietaryPreference),
        excludedIngredients: excludedIngredients ?? this.excludedIngredients,
        cuisine: clearCuisine ? null : (cuisine ?? this.cuisine),
      );

  Map<String, Object?> toRow() => {
        'id': 'default',
        'meal_type_filters': mealType?.dbValue,
        'max_time_minutes': maxMinutes,
        'difficulty_filter': difficulty?.dbValue,
        'dietary_preferences': dietaryPreference,
        'excluded_ingredients': jsonEncode(excludedIngredients),
        'cuisine_preferences': cuisine,
        'match_mode': matchMode.dbValue,
        'use_soon_first': useSoonFirst ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory MealPreferences.fromRow(Map<String, Object?> r) {
    final meal = r['meal_type_filters'] as String?;
    final diff = r['difficulty_filter'] as String?;
    return MealPreferences(
      mealType: meal == null ? null : MealType.fromDb(meal),
      maxMinutes: r['max_time_minutes'] as int?,
      difficulty: diff == null ? null : Difficulty.fromDb(diff),
      matchMode: PantryMatchMode.fromDb(r['match_mode'] as String?),
      useSoonFirst: (r['use_soon_first'] as int? ?? 1) == 1,
      dietaryPreference: r['dietary_preferences'] as String?,
      excludedIngredients:
          (jsonDecode(r['excluded_ingredients'] as String? ?? '[]') as List)
              .cast<String>(),
      cuisine: r['cuisine_preferences'] as String?,
    );
  }
}
