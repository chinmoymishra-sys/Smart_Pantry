import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/pantry_enums.dart';
import '../../../providers/repository_providers.dart';
import '../../inventory/controllers/inventory_controller.dart';
import '../models/meal_preferences.dart';
import '../models/recipe.dart';
import '../models/recipe_match.dart';

class RecipesController extends AsyncNotifier<List<Recipe>> {
  @override
  Future<List<Recipe>> build() => ref.read(recipeRepositoryProvider).getRecipes();

  Future<void> toggleFavorite(String id) async {
    final list = state.value ?? const <Recipe>[];
    final r = list.firstWhere((x) => x.id == id);
    await ref.read(recipeRepositoryProvider).setFavorite(id, !r.isFavorite);
    state = AsyncData([
      for (final x in list) x.id == id ? x.copyWith(isFavorite: !x.isFavorite) : x,
    ]);
  }

  Future<void> setFavorite(String id, bool favorite) async {
    final list = state.value ?? const <Recipe>[];
    await ref.read(recipeRepositoryProvider).setFavorite(id, favorite);
    state = AsyncData([
      for (final x in list) x.id == id ? x.copyWith(isFavorite: favorite) : x,
    ]);
  }
}

final recipesProvider =
    AsyncNotifierProvider<RecipesController, List<Recipe>>(RecipesController.new);

final recipeProvider = Provider.family<Recipe?, String>((ref, id) {
  for (final r in ref.watch(recipesProvider).value ?? const <Recipe>[]) {
    if (r.id == id) return r;
  }
  return null;
});

class MealPreferencesController extends AsyncNotifier<MealPreferences> {
  @override
  Future<MealPreferences> build() =>
      ref.read(recipeRepositoryProvider).getPreferences();

  Future<void> save(MealPreferences prefs) async {
    state = AsyncData(prefs);
    await ref.read(recipeRepositoryProvider).savePreferences(prefs);
  }

  Future<void> setMealType(MealType? type) => save(
      (state.value ?? const MealPreferences())
          .copyWith(mealType: type, clearMealType: type == null));

  Future<void> toggleUseSoonFirst() {
    final p = state.value ?? const MealPreferences();
    return save(p.copyWith(useSoonFirst: !p.useSoonFirst));
  }

  /// Widen the search: keep meal type, drop every other restriction.
  Future<void> reset() => save(MealPreferences(
        mealType: state.value?.mealType,
        useSoonFirst: state.value?.useSoonFirst ?? true,
      ));

  Future<void> clearAll() => save(const MealPreferences());
}

final mealPreferencesProvider =
    AsyncNotifierProvider<MealPreferencesController, MealPreferences>(
        MealPreferencesController.new);

const _matcher = RecipeMatcher();

/// Every recipe matched against confirmed inventory (no preference filters).
final allRecipeMatchesProvider = Provider<AsyncValue<List<RecipeMatch>>>((ref) {
  final recipes = ref.watch(recipesProvider);
  final items = ref.watch(inventoryProvider);
  if (recipes is AsyncError) return AsyncError(recipes.error!, recipes.stackTrace!);
  if (items is AsyncError) return AsyncError(items.error!, items.stackTrace!);
  final r = recipes.value, i = items.value;
  if (r == null || i == null) return const AsyncLoading();
  return AsyncData([for (final x in r) _matcher.match(x, i)]);
});

final recipeMatchProvider =
    Provider.family<RecipeMatch?, ({String recipeId, int? servings})>(
        (ref, args) {
  final recipe = ref.watch(recipeProvider(args.recipeId));
  final items = ref.watch(inventoryProvider).value;
  if (recipe == null || items == null) return null;
  return _matcher.match(recipe, items, servings: args.servings);
});

bool _passes(RecipeMatch m, MealPreferences p) {
  final r = m.recipe;
  if (p.mealType != null && r.mealType != p.mealType) return false;
  // "Under N min" — total time strictly below N.
  if (p.maxMinutes != null && r.totalMinutes >= p.maxMinutes!) return false;
  if (p.difficulty != null && r.difficulty != p.difficulty) return false;
  if (p.matchMode == PantryMatchMode.availableOnly && !m.isFullyAvailable) {
    return false;
  }
  if (p.dietaryPreference != null &&
      !r.dietTags.contains(p.dietaryPreference)) {
    return false;
  }
  if (p.cuisine != null && !r.cuisines.contains(p.cuisine)) return false;
  for (final ex in p.excludedIngredients) {
    final e = ex.trim().toLowerCase();
    if (e.isEmpty) continue;
    if (r.ingredients.any((i) =>
        i.name.toLowerCase().contains(e) ||
        i.matchKeys.any((k) => k.contains(e)))) {
      return false;
    }
  }
  return true;
}

List<RecipeMatch> filterAndSortMatches(
    List<RecipeMatch> all, MealPreferences p) {
  final list = all.where((m) => _passes(m, p)).toList();
  int mealOrder(RecipeMatch m) => m.recipe.mealType.index;
  list.sort((a, b) {
    if (p.useSoonFirst) {
      final au = a.usesUseSoonItem ? 0 : 1, bu = b.usesUseSoonItem ? 0 : 1;
      if (au != bu && p.mealType != null) return au - bu;
    }
    if (p.matchMode == PantryMatchMode.fewestMissing) {
      final c = a.missingRequiredCount.compareTo(b.missingRequiredCount);
      if (c != 0) return c;
    }
    return mealOrder(a).compareTo(mealOrder(b));
  });
  return list;
}

/// Matches filtered and ordered by the saved preferences.
final filteredRecipeMatchesProvider =
    Provider<AsyncValue<List<RecipeMatch>>>((ref) {
  final prefs = ref.watch(mealPreferencesProvider);
  final all = ref.watch(allRecipeMatchesProvider);
  final p = prefs.value;
  if (p == null) return const AsyncLoading();
  return all.whenData((list) => filterAndSortMatches(list, p));
});

/// The available-match the use-soon banner highlights, if any.
final useSoonHighlightProvider = Provider<RecipeMatch?>((ref) {
  final list = ref.watch(filteredRecipeMatchesProvider).value;
  if (list == null) return null;
  RecipeMatch? best;
  DateTime? bestDate;
  for (final m in list) {
    final d = m.earliestUseSoonDate;
    if (d != null && (bestDate == null || d.isBefore(bestDate))) {
      best = m;
      bestDate = d;
    }
  }
  return best;
});
