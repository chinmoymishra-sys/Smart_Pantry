import '../../../core/utils/units.dart';
import '../../inventory/models/pantry_item.dart';
import 'recipe.dart';

enum IngredientAvailability {
  /// Stocked in a comparable unit with enough quantity.
  available,

  /// Stocked but not enough of it.
  insufficient,

  /// Stocked, but the units can't be compared reliably (e.g. pieces vs g).
  unitMismatch,

  /// Not stocked, out, or marked unavailable.
  missing,
}

class IngredientMatch {
  const IngredientMatch({
    required this.ingredient,
    required this.availability,
    this.pantryItem,
    this.availableQuantity,
  });

  final RecipeIngredient ingredient;
  final IngredientAvailability availability;
  final PantryItem? pantryItem;

  /// Stock converted to the ingredient's unit (null if not comparable).
  final double? availableQuantity;

  bool get isAvailable => availability == IngredientAvailability.available;

  /// "have 150 g" / "have 2 tins · 240 g drained per tin"
  String? get haveLabel {
    final item = pantryItem;
    if (item == null) return null;
    final pkg = item.packageContentLabel;
    return 'have ${item.quantityLabel}${pkg == null ? '' : ' · $pkg'}';
  }
}

class RecipeMatch {
  const RecipeMatch({
    required this.recipe,
    required this.servings,
    required this.ingredients,
  });

  final Recipe recipe;
  final int servings;
  final List<IngredientMatch> ingredients;

  List<IngredientMatch> get required =>
      ingredients.where((m) => m.ingredient.isRequired).toList();
  List<IngredientMatch> get optional =>
      ingredients.where((m) => !m.ingredient.isRequired).toList();

  int get requiredCount => required.length;
  int get availableRequiredCount => required.where((m) => m.isAvailable).length;
  int get missingRequiredCount => requiredCount - availableRequiredCount;
  bool get isFullyAvailable => missingRequiredCount == 0;

  List<IngredientMatch> get availableRequired =>
      required.where((m) => m.isAvailable).toList();
  List<IngredientMatch> get missingRequired =>
      required.where((m) => !m.isAvailable).toList();

  bool get usesUseSoonItem =>
      required.any((m) => m.isAvailable && (m.pantryItem?.isUseSoon ?? false));

  /// Earliest recorded date among matched available items (for sorting).
  DateTime? get earliestUseSoonDate {
    DateTime? best;
    for (final m in required) {
      final d = m.pantryItem?.expiryDate;
      if (m.isAvailable && (m.pantryItem?.isUseSoon ?? false) && d != null) {
        if (best == null || d.isBefore(best)) best = d;
      }
    }
    return best;
  }
}

/// Deterministic pantry matching against confirmed inventory quantities.
///
/// * Only required ingredients decide availability; optional ones never do.
/// * Out-of-stock and unavailable items never count as available.
/// * Units are compared only when compatible; otherwise the ingredient is
///   reported as [IngredientAvailability.unitMismatch] (not available).
class RecipeMatcher {
  const RecipeMatcher();

  static String _singular(String s) {
    if (s.endsWith('oes')) return s.substring(0, s.length - 2);
    if (s.endsWith('ies')) return '${s.substring(0, s.length - 3)}y';
    if (s.endsWith('s') && !s.endsWith('ss')) {
      return s.substring(0, s.length - 1);
    }
    return s;
  }

  static bool nameMatches(String pantryName, List<String> keys) {
    final p = _singular(PantryItem.normalize(pantryName));
    for (final raw in keys) {
      final k = _singular(PantryItem.normalize(raw));
      if (p == k) return true;
      // "plain yogurt" matches key "yogurt"; "green peas" matches "green pea".
      if (RegExp('(^| )${RegExp.escape(k)}( |\$)').hasMatch(p)) return true;
    }
    return false;
  }

  RecipeMatch match(Recipe recipe, List<PantryItem> pantry, {int? servings}) {
    final s = servings ?? recipe.servings;
    final factor = s / recipe.servings;
    final results = <IngredientMatch>[];
    for (final base in recipe.ingredients) {
      final ing = base.scaled(factor);
      final candidates = pantry
          .where((p) => p.isUsable && nameMatches(p.name, ing.matchKeys))
          .toList();
      if (candidates.isEmpty) {
        results.add(IngredientMatch(
          ingredient: ing,
          availability: IngredientAvailability.missing,
        ));
        continue;
      }
      // Prefer a candidate with a comparable unit, then the earliest date.
      candidates.sort((a, b) {
        final ac = a.unit.isCompatibleWith(ing.unit) ? 0 : 1;
        final bc = b.unit.isCompatibleWith(ing.unit) ? 0 : 1;
        if (ac != bc) return ac - bc;
        final ad = a.expiryDate, bd = b.expiryDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
      final item = candidates.first;
      final have = tryConvertQuantity(item.quantity, item.unit, ing.unit);
      final IngredientAvailability availability;
      if (have == null) {
        availability = IngredientAvailability.unitMismatch;
      } else if (have + 1e-9 >= ing.quantity) {
        availability = IngredientAvailability.available;
      } else {
        availability = IngredientAvailability.insufficient;
      }
      results.add(IngredientMatch(
        ingredient: ing,
        availability: availability,
        pantryItem: item,
        availableQuantity: have,
      ));
    }
    return RecipeMatch(recipe: recipe, servings: s, ingredients: results);
  }
}
