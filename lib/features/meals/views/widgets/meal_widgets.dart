import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../cooking/controllers/cooking_controller.dart';
import '../../../cooking/models/cooking_models.dart';
import '../../controllers/meals_controller.dart';
import '../../models/meal_preferences.dart';
import '../../models/recipe.dart';
import '../../models/recipe_match.dart';

/// Last word of the recipe name, lower-cased ("Spinach chickpea skillet" →
/// "skillet"), as used in the design's short references.
String shortRecipeName(Recipe r) {
  final parts = r.name.trim().split(RegExp(r'\s+'));
  return parts.isEmpty ? r.name.toLowerCase() : parts.last.toLowerCase();
}

String lowerFirst(String s) =>
    s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';

/// Planned amount in compact form: piece counts show only the number
/// ("Tomatoes 2"), everything else keeps its unit ("Oats 50 g").
String plannedAmount(RecipeIngredient i) {
  if (i.displayQuantity != null) return i.displayQuantity!;
  if (i.unit == PantryUnit.pieces) return formatNumber(i.quantity);
  return formatQuantity(i.quantity, i.unit);
}

/// "Under 15 min" etc.
String timeLabel(int? minutes) =>
    minutes == null ? 'Any time' : 'Under $minutes min';

/// "lunch", "breakfast", "snack" or "meal" (for "Show 2 lunch ideas").
String mealWord(MealType? t) => switch (t) {
      null => 'meal',
      MealType.snacks => 'snack',
      _ => t.label.toLowerCase(),
    };

/// Human-readable labels of the active (non-meal-type) filters.
List<String> activeFilterLabels(MealPreferences p) => [
      if (p.matchMode != PantryMatchMode.any) p.matchMode.label,
      if (p.maxMinutes != null) timeLabel(p.maxMinutes),
      if (p.difficulty != null) p.difficulty!.label,
      if (p.dietaryPreference != null) p.dietaryPreference!,
      if (p.cuisine != null) p.cuisine!,
      for (final e in p.excludedIngredients) 'No $e',
    ];

/// Number of filters set on the Meal filters screen (meal type excluded,
/// it has its own chips).
int activeFilterCount(MealPreferences p) =>
    (p.matchMode != PantryMatchMode.any ? 1 : 0) +
    (p.maxMinutes != null ? 1 : 0) +
    (p.difficulty != null ? 1 : 0) +
    (p.dietaryPreference != null ? 1 : 0) +
    (p.cuisine != null ? 1 : 0) +
    (p.excludedIngredients.isNotEmpty ? 1 : 0);

/// Honest one-line explanation for a required ingredient that isn't covered.
String shortfallLabel(IngredientMatch m) {
  final i = m.ingredient;
  final need = formatQuantity(i.quantity, i.unit);
  final have = m.pantryItem?.quantityLabel;
  return switch (m.availability) {
    IngredientAvailability.insufficient => '${i.name} · need $need, have $have',
    IngredientAvailability.unitMismatch =>
      '${i.name} · recipe uses $need, you recorded $have',
    _ => '${i.name} · ${i.amountLabel}',
  };
}

/// Image art direction: a few recipes have dedicated photos for the detail,
/// instructions and "missing ingredient" views; others reuse the card photo.
abstract final class RecipeImages {
  static const _detail = {
    'spinach-chickpea-skillet': 'assets/images/recipe_detail_skillet.jpg',
  };
  static const _instructions = {
    'spinach-chickpea-skillet': 'assets/images/recipe_instructions_skillet.jpg',
  };
  static const _missing = {
    'paneer-tomato-toast': 'assets/images/paneer_tomato_toast_missing.jpg',
  };

  static const _cooking = {
    'spinach-chickpea-skillet':
        'assets/images/spinach_chickpea_skillet_cooking.jpg',
  };
  static const _paused = {
    'spinach-chickpea-skillet':
        'assets/images/spinach_chickpea_skillet_paused.jpg',
  };
  static const _finished = {
    'spinach-chickpea-skillet':
        'assets/images/spinach_chickpea_skillet_finished.jpg',
  };
  static const _success = {
    'spinach-chickpea-skillet': 'assets/images/cooking_success_skillet.jpg',
  };

  static String cooking(Recipe r) => _cooking[r.id] ?? r.imagePath;
  static String paused(Recipe r) => _paused[r.id] ?? r.imagePath;
  static String finished(Recipe r) => _finished[r.id] ?? r.imagePath;
  static String success(Recipe r) => _success[r.id] ?? r.imagePath;
  static String detail(Recipe r) => _detail[r.id] ?? r.imagePath;
  static String instructions(Recipe r) => _instructions[r.id] ?? r.imagePath;
  static String missing(Recipe r) => _missing[r.id] ?? r.imagePath;
  static String thumb(Recipe r) => r.thumbnailPath ?? r.imagePath;
}

/// Starts (or resumes) a cooking session and opens step-by-step mode.
/// Starting never changes inventory. Asks before replacing a different
/// open session.
Future<void> startCookingFlow(
  BuildContext context,
  WidgetRef ref,
  Recipe recipe,
  int servings,
) async {
  final open = ref.read(cookingControllerProvider).value;
  if (open != null && open.status.isOpen && open.recipeId != recipe.id) {
    final ok = await showConfirmDialog(
      context,
      title: 'Start ${lowerFirst(recipe.name)} instead?',
      body: 'You have ${lowerFirst(open.recipeName)} in progress. Starting a '
          'new recipe closes that session. Your inventory doesn’t change.',
      confirmLabel: 'Start ${lowerFirst(recipe.name)}',
      cancelLabel: 'Keep current session',
    );
    if (!ok || !context.mounted) return;
  }
  try {
    await ref
        .read(cookingControllerProvider.notifier)
        .start(recipe, servings: servings);
    if (context.mounted) context.push(Routes.cookStep);
  } catch (e) {
    if (context.mounted) showAppSnack(context, friendlyError(e));
  }
}

/// Whether a cooking session is open (watching).
bool watchHasOpenCooking(WidgetRef ref) {
  final s = ref.watch(cookingControllerProvider).value;
  return s != null && s.status.isOpen;
}

/// "Continue cooking …" card shown while a cooking session is open.
class ContinueCookingCard extends ConsumerWidget {
  const ContinueCookingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CookingSession? s = ref.watch(cookingControllerProvider).value;
    if (s == null || !s.status.isOpen) return const SizedBox.shrink();
    final c = context.colors;
    final recipe = ref.watch(recipeProvider(s.recipeId));
    final total = recipe?.steps.length;
    final paused = s.status == CookingStatus.paused;
    return AppCard(
      onTap: () => context.go(Routes.cookResume),
      child: Row(
        children: [
          Icon(LucideIcons.utensils, size: 22, color: c.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Continue cooking ${lowerFirst(s.recipeName)}',
                    style: AppTypography.titleStrong
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${total == null ? 'Step ${s.currentStep}' : 'Step ${s.currentStep} of $total'}'
                  '${paused ? ' · paused' : ''} · pantry unchanged until you confirm',
                  style: AppTypography.body.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 20, color: c.textPrimary),
        ],
      ),
    );
  }
}

/// Label/value rows (140px label column) with an optional value colour.
class IngredientRows extends StatelessWidget {
  const IngredientRows(this.rows, {super.key, this.valueColor, this.labelColor});

  final List<(String, String)> rows;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(rows[i].$1,
                    style: AppTypography.body
                        .copyWith(color: labelColor ?? c.textMuted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(rows[i].$2,
                    style: AppTypography.body
                        .copyWith(color: valueColor ?? c.textPrimary)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Small loading card: "Refreshing lunch ideas".
class MealsLoadingCard extends StatelessWidget {
  const MealsLoadingCard({super.key, this.mealType});
  final MealType? mealType;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StateCard(
      overline: 'Meals · section loading',
      title: 'Refreshing ${mealWord(mealType)} ideas',
      body: 'Your inventory and other meals remain available while this '
          'section updates.',
      extra: SizedBox(
        height: 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            color: c.textPrimary,
            backgroundColor: c.surfaceMuted,
          ),
        ),
      ),
    );
  }
}
