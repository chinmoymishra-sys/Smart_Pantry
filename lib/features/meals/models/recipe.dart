import 'dart:convert';

import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/units.dart';

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.name,
    required this.matchKeys,
    required this.quantity,
    required this.unit,
    required this.isRequired,
    required this.displayOrder,
    this.displayQuantity,
    this.preparation,
  });

  final String id;
  final String recipeId;

  /// Display name, e.g. "Spinach".
  final String name;

  /// Normalised names that identify this ingredient in pantry records,
  /// e.g. ["spinach"] or ["yogurt", "plain yogurt"].
  final List<String> matchKeys;
  final double quantity;
  final PantryUnit unit;
  final bool isRequired;
  final int displayOrder;

  /// Optional display override (e.g. "½ lemon").
  final String? displayQuantity;

  /// Preparation note shown while cooking (e.g. "washed and chopped").
  final String? preparation;

  String get amountLabel => displayQuantity ?? formatQuantity(quantity, unit);

  RecipeIngredient scaled(double factor) => RecipeIngredient(
        id: id,
        recipeId: recipeId,
        name: name,
        matchKeys: matchKeys,
        quantity: quantity * factor,
        unit: unit,
        isRequired: isRequired,
        displayOrder: displayOrder,
        displayQuantity: factor == 1 ? displayQuantity : null,
        preparation: preparation,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'recipe_id': recipeId,
        'ingredient_name': name,
        'normalized_ingredient_name': matchKeys.first,
        'match_keys': jsonEncode(matchKeys),
        'quantity': quantity,
        'unit': unit.dbValue,
        'display_quantity': displayQuantity,
        'preparation': preparation,
        'is_required': isRequired ? 1 : 0,
        'display_order': displayOrder,
      };

  factory RecipeIngredient.fromRow(Map<String, Object?> r) => RecipeIngredient(
        id: r['id']! as String,
        recipeId: r['recipe_id']! as String,
        name: r['ingredient_name']! as String,
        matchKeys: (jsonDecode(r['match_keys'] as String? ?? '[]') as List)
            .cast<String>(),
        quantity: (r['quantity']! as num).toDouble(),
        unit: PantryUnit.fromDb(r['unit'] as String?),
        isRequired: (r['is_required'] as int? ?? 1) == 1,
        displayOrder: r['display_order'] as int? ?? 0,
        displayQuantity: r['display_quantity'] as String?,
        preparation: r['preparation'] as String?,
      );
}

class RecipeStep {
  const RecipeStep({
    required this.id,
    required this.recipeId,
    required this.stepNumber,
    required this.title,
    required this.instruction,
    this.headline,
    this.durationSeconds,
    this.timerNote,
  });

  final String id;
  final String recipeId;
  final int stepNumber;
  final String title;

  /// Full method text shown on the instructions screen.
  final String instruction;

  /// Larger first sentence shown in focused cooking mode (optional).
  final String? headline;
  final int? durationSeconds;
  final String? timerNote;

  String? get durationLabel {
    final s = durationSeconds;
    if (s == null) return null;
    final m = (s / 60).round();
    return 'About $m minute${m == 1 ? '' : 's'}';
  }

  /// Body text for focused mode: instruction minus the headline sentence.
  String get cookingBody {
    final h = headline;
    if (h == null) return instruction;
    return instruction.startsWith(h)
        ? instruction.substring(h.length).trim()
        : instruction;
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'recipe_id': recipeId,
        'step_number': stepNumber,
        'title': title,
        'instruction': instruction,
        'headline': headline,
        'duration_seconds': durationSeconds,
        'timer_note': timerNote,
      };

  factory RecipeStep.fromRow(Map<String, Object?> r) => RecipeStep(
        id: r['id']! as String,
        recipeId: r['recipe_id']! as String,
        stepNumber: r['step_number']! as int,
        title: r['title']! as String,
        instruction: r['instruction']! as String,
        headline: r['headline'] as String?,
        durationSeconds: r['duration_seconds'] as int?,
        timerNote: r['timer_note'] as String?,
      );
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.mealType,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.servings,
    required this.cuisines,
    required this.dietTags,
    required this.equipment,
    required this.imagePath,
    required this.ingredients,
    required this.steps,
    this.summary,
    this.thumbnailPath,
    this.optionalNote,
    this.isFavorite = false,
  });

  final String id;
  final String name;

  /// Short card description ("Tender greens, tomatoes and golden chickpeas.")
  final String description;

  /// Detail subtitle ("A quick, comforting lunch for two.")
  final String? summary;
  final MealType mealType;
  final int prepMinutes;
  final int cookMinutes;
  final Difficulty difficulty;
  final int servings;
  final List<String> cuisines;
  final List<String> dietTags;
  final String equipment;
  final String imagePath;
  final String? thumbnailPath;

  /// Hint for optional ingredients ("Skip it or add a squeeze to finish.")
  final String? optionalNote;
  final bool isFavorite;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  int get totalMinutes => prepMinutes + cookMinutes;
  List<RecipeIngredient> get required =>
      ingredients.where((i) => i.isRequired).toList();
  List<RecipeIngredient> get optional =>
      ingredients.where((i) => !i.isRequired).toList();

  Recipe copyWith({bool? isFavorite}) => Recipe(
        id: id,
        name: name,
        description: description,
        summary: summary,
        mealType: mealType,
        prepMinutes: prepMinutes,
        cookMinutes: cookMinutes,
        difficulty: difficulty,
        servings: servings,
        cuisines: cuisines,
        dietTags: dietTags,
        equipment: equipment,
        imagePath: imagePath,
        thumbnailPath: thumbnailPath,
        optionalNote: optionalNote,
        isFavorite: isFavorite ?? this.isFavorite,
        ingredients: ingredients,
        steps: steps,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'description': description,
        'summary': summary,
        'meal_type': mealType.dbValue,
        'prep_minutes': prepMinutes,
        'cook_minutes': cookMinutes,
        'difficulty': difficulty.dbValue,
        'servings': servings,
        'cuisine': jsonEncode(cuisines),
        'diet_tags': jsonEncode(dietTags),
        'equipment': equipment,
        'image_path': imagePath,
        'thumbnail_path': thumbnailPath,
        'optional_note': optionalNote,
        'is_favorite': isFavorite ? 1 : 0,
      };

  factory Recipe.fromRow(
    Map<String, Object?> r,
    List<RecipeIngredient> ingredients,
    List<RecipeStep> steps,
  ) =>
      Recipe(
        id: r['id']! as String,
        name: r['name']! as String,
        description: r['description'] as String? ?? '',
        summary: r['summary'] as String?,
        mealType: MealType.fromDb(r['meal_type'] as String?),
        prepMinutes: r['prep_minutes'] as int? ?? 0,
        cookMinutes: r['cook_minutes'] as int? ?? 0,
        difficulty: Difficulty.fromDb(r['difficulty'] as String?),
        servings: r['servings'] as int? ?? 1,
        cuisines:
            (jsonDecode(r['cuisine'] as String? ?? '[]') as List).cast<String>(),
        dietTags: (jsonDecode(r['diet_tags'] as String? ?? '[]') as List)
            .cast<String>(),
        equipment: r['equipment'] as String? ?? '',
        imagePath: r['image_path'] as String? ?? '',
        thumbnailPath: r['thumbnail_path'] as String?,
        optionalNote: r['optional_note'] as String?,
        isFavorite: (r['is_favorite'] as int? ?? 0) == 1,
        ingredients: ingredients,
        steps: steps,
      );
}
