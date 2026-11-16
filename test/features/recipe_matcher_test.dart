import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pantry/core/enums/pantry_enums.dart';
import 'package:smart_pantry/core/utils/units.dart';
import 'package:smart_pantry/data/database/recipe_seed.dart';
import 'package:smart_pantry/features/meals/controllers/meals_controller.dart';
import 'package:smart_pantry/features/meals/models/meal_preferences.dart';
import 'package:smart_pantry/features/meals/models/recipe_match.dart';

import '../helpers/fixtures.dart';

void main() {
  setUp(pinToday);

  final recipes = RecipeSeed.recipes;
  final skillet = recipes.firstWhere((r) => r.id == 'spinach-chickpea-skillet');
  final toast = recipes.firstWhere((r) => r.id == 'paneer-tomato-toast');
  const matcher = RecipeMatcher();

  // The design's 12-item household.
  final pantry = [
    item('Spinach', 150, PantryUnit.g, expiry: DateTime(2026, 11, 8)),
    item('Plain yogurt', 400, PantryUnit.g, state: FoodState.packaged),
    item('Tomatoes', 4, PantryUnit.pieces),
    item('Milk', 1, PantryUnit.l),
    item('Paneer', 200, PantryUnit.g),
    item('Eggs', 6, PantryUnit.pieces),
    item('Green peas', 300, PantryUnit.g, storage: StorageLocation.freezer),
    item('Blueberries', 250, PantryUnit.g, storage: StorageLocation.freezer),
    item('Chickpeas', 2, PantryUnit.tins, storage: StorageLocation.pantry),
    item('Oats', 500, PantryUnit.g, storage: StorageLocation.pantry),
    item('Rice', 1, PantryUnit.kg, storage: StorageLocation.pantry),
    item('Olive oil', 50, PantryUnit.ml,
        storage: StorageLocation.pantry, lowStock: 60),
  ];

  test('skillet: all 4 required available; optional lemon ignored', () {
    final m = matcher.match(skillet, pantry);
    expect(m.requiredCount, 4);
    expect(m.availableRequiredCount, 4);
    expect(m.isFullyAvailable, isTrue);
    expect(m.optional.single.availability, IngredientAvailability.missing);
    expect(m.usesUseSoonItem, isTrue);
  });

  test('toast: bread is a required missing ingredient', () {
    final m = matcher.match(toast, pantry);
    expect(m.availableRequiredCount, 2);
    expect(m.missingRequired.single.ingredient.name, 'Bread');
    expect(m.isFullyAvailable, isFalse);
  });

  test('rice in kg satisfies a gram requirement (compatible units)', () {
    final rice = recipes.firstWhere((r) => r.id == 'peas-onion-rice');
    final m = matcher.match(rice, pantry);
    final r = m.required.firstWhere((i) => i.ingredient.name == 'Rice');
    expect(r.isAvailable, isTrue);
    expect(r.availableQuantity, 1000);
    expect(m.missingRequired.single.ingredient.name, 'Onion');
  });

  test('unavailable and out-of-stock items never count as available', () {
    final p = [
      ...pantry.where((i) => i.name != 'Spinach'),
      item('Spinach', 150, PantryUnit.g, unavailable: true),
    ];
    expect(matcher.match(skillet, p).availableRequiredCount, 3);
    final p2 = [
      ...pantry.where((i) => i.name != 'Spinach'),
      item('Spinach', 0, PantryUnit.g),
    ];
    expect(matcher.match(skillet, p2).availableRequiredCount, 3);
  });

  test('insufficient quantity is not available', () {
    final p = [
      ...pantry.where((i) => i.name != 'Spinach'),
      item('Spinach', 50, PantryUnit.g),
    ];
    final s = matcher.match(skillet, p).required.first;
    expect(s.availability, IngredientAvailability.insufficient);
  });

  test('incompatible units are reported, not guessed', () {
    final p = [
      ...pantry.where((i) => i.name != 'Spinach'),
      item('Spinach', 1, PantryUnit.packets),
    ];
    final s = matcher.match(skillet, p).required.first;
    expect(s.availability, IngredientAvailability.unitMismatch);
    expect(s.isAvailable, isFalse);
  });

  test('servings scale required quantities', () {
    final m = matcher.match(skillet, pantry, servings: 4);
    final spinach = m.required.first;
    expect(spinach.ingredient.quantity, 200);
    expect(spinach.availability, IngredientAvailability.insufficient);
  });

  test('preferences: available only + under 15 min yields no lunch ideas', () {
    final all = [for (final r in recipes) matcher.match(r, pantry)];
    final res = filterAndSortMatches(
      all,
      const MealPreferences(
        mealType: MealType.lunch,
        maxMinutes: 15,
        matchMode: PantryMatchMode.availableOnly,
      ),
    );
    expect(res, isEmpty);
    final lunch = filterAndSortMatches(
        all, const MealPreferences(mealType: MealType.lunch));
    expect(lunch.single.recipe.id, skillet.id);
  });

  test('excluded ingredients remove recipes', () {
    final all = [for (final r in recipes) matcher.match(r, pantry)];
    final res = filterAndSortMatches(
        all, const MealPreferences(excludedIngredients: ['paneer']));
    expect(res.any((m) => m.recipe.id == toast.id), isFalse);
  });

  test('name matching handles plurals and qualifiers', () {
    expect(RecipeMatcher.nameMatches('Plain yogurt', ['yogurt']), isTrue);
    expect(RecipeMatcher.nameMatches('Tomato', ['tomatoes']), isTrue);
    expect(RecipeMatcher.nameMatches('Green peas', ['peas']), isTrue);
    expect(RecipeMatcher.nameMatches('Chickpea flour', ['chickpeas']), isTrue);
    expect(RecipeMatcher.nameMatches('Ricotta', ['rice']), isFalse);
  });
}
