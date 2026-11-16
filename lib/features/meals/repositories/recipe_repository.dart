import '../models/meal_preferences.dart';
import '../models/recipe.dart';

abstract interface class RecipeRepository {
  Future<List<Recipe>> getRecipes();
  Future<void> setFavorite(String recipeId, bool favorite);
  Future<MealPreferences> getPreferences();
  Future<void> savePreferences(MealPreferences prefs);
}
