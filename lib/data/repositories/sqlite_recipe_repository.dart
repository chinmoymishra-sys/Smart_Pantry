import 'package:sqflite/sqflite.dart';

import '../../features/meals/models/meal_preferences.dart';
import '../../features/meals/models/recipe.dart';
import '../../features/meals/repositories/recipe_repository.dart';

class SqliteRecipeRepository implements RecipeRepository {
  SqliteRecipeRepository(this._db);
  final Database _db;

  @override
  Future<List<Recipe>> getRecipes() async {
    final recipes = await _db.query('recipes', orderBy: 'rowid ASC');
    final ingRows =
        await _db.query('recipe_ingredients', orderBy: 'display_order ASC');
    final stepRows =
        await _db.query('recipe_steps', orderBy: 'step_number ASC');
    final ings = <String, List<RecipeIngredient>>{};
    for (final r in ingRows) {
      final i = RecipeIngredient.fromRow(r);
      (ings[i.recipeId] ??= []).add(i);
    }
    final steps = <String, List<RecipeStep>>{};
    for (final r in stepRows) {
      final s = RecipeStep.fromRow(r);
      (steps[s.recipeId] ??= []).add(s);
    }
    return recipes.map((r) {
      final id = r['id']! as String;
      return Recipe.fromRow(r, ings[id] ?? const [], steps[id] ?? const []);
    }).toList();
  }

  @override
  Future<void> setFavorite(String recipeId, bool favorite) => _db.update(
        'recipes',
        {'is_favorite': favorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [recipeId],
      );

  @override
  Future<MealPreferences> getPreferences() async {
    final rows = await _db.query('meal_preferences',
        where: 'id = ?', whereArgs: ['default'], limit: 1);
    return rows.isEmpty
        ? const MealPreferences()
        : MealPreferences.fromRow(rows.first);
  }

  @override
  Future<void> savePreferences(MealPreferences prefs) => _db.insert(
        'meal_preferences',
        prefs.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
}
