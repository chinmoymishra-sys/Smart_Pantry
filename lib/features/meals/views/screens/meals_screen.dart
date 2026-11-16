import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../controllers/meals_controller.dart';
import '../../models/meal_preferences.dart';
import '../../models/recipe_match.dart';
import '../widgets/meal_widgets.dart';
import '../widgets/recipe_card.dart';

/// "What can I cook?" — recipes matched against confirmed inventory.
class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) showAppSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(mealPreferencesProvider);
    final prefs = prefsAsync.value ?? const MealPreferences();
    final matches = ref.watch(filteredRecipeMatchesProvider);
    final highlight = ref.watch(useSoonHighlightProvider);
    final notifier = ref.read(mealPreferencesProvider.notifier);
    final count = activeFilterCount(prefs);

    final List<Widget> body;
    if (prefsAsync.hasError) {
      body = [
        ErrorStateView(
          error: prefsAsync.error!,
          onRetry: () => ref.invalidate(mealPreferencesProvider),
        ),
      ];
    } else {
      body = matches.when(
        loading: () => [MealsLoadingCard(mealType: prefs.mealType)],
        error: (e, _) => [
          ErrorStateView(
            error: e,
            onRetry: () {
              ref.invalidate(recipesProvider);
            },
          ),
        ],
        data: (list) => list.isEmpty
            ? [_NoMatches(prefs: prefs)]
            : [
                if (highlight != null && _highlightText(highlight) != null)
                  InfoCallout(
                    title: _highlightText(highlight)!.$1,
                    body: _highlightText(highlight)!.$2,
                  ),
                for (final m in list) RecipeCard(match: m),
              ],
      );
    }

    return AppPage(
      title: 'What can I cook?',
      subtitle: 'Good food starts with what’s already here.',
      showBack: false,
      children: [
        if (watchHasOpenCooking(ref)) const ContinueCookingCard(),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: count == 0 ? 'Filters' : 'Filters · $count',
                icon: LucideIcons.slidersHorizontal,
                onPressed: () => context.push(Routes.mealFilters),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ToggleButton(
                label: 'Use soon first',
                icon: LucideIcons.leaf,
                selected: prefs.useSoonFirst,
                onPressed: () =>
                    _run(context, () => notifier.toggleUseSoonFirst()),
              ),
            ),
          ],
        ),
        ChipWrap(
          children: [
            AppChip(
              label: 'All meals',
              selected: prefs.mealType == null,
              onTap: () => _run(context, () => notifier.setMealType(null)),
            ),
            for (final t in MealType.values)
              AppChip(
                label: t.label,
                selected: prefs.mealType == t,
                onTap: () => _run(context, () => notifier.setMealType(t)),
              ),
          ],
        ),
        ...body,
        const Footnote(
          'Matches use confirmed quantities, not photos. Suggestions reflect '
          'selected preferences, not allergy guarantees. Photos are '
          'illustrative.',
        ),
      ],
    );
  }

  /// ("Make the most of your spinach", "Your recorded use-by date is 8 Nov.
  /// The lunch skillet uses 100 g of your 150 g.")
  static (String, String)? _highlightText(RecipeMatch m) {
    final d = m.earliestUseSoonDate;
    if (d == null) return null;
    IngredientMatch? ing;
    for (final x in m.availableRequired) {
      if (x.pantryItem?.expiryDate == d && (x.pantryItem?.isUseSoon ?? false)) {
        ing = x;
        break;
      }
    }
    final item = ing?.pantryItem;
    if (ing == null || item == null) return null;
    final r = m.recipe;
    return (
      'Make the most of your ${item.name.toLowerCase()}',
      'Your recorded ${item.dateType.label.toLowerCase().replaceAll(' ', '-')} '
          'date is ${AppDates.short(d)}. The ${r.mealType.label.toLowerCase()} '
          '${shortRecipeName(r)} uses ${ing.ingredient.amountLabel} of your '
          '${item.quantityLabel}.',
    );
  }
}

/// Secondary-style button that shows a selected state (border + check).
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      toggled: selected,
      child: Material(
        color: selected ? c.surfaceMuted : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.buttonRadius,
          side: BorderSide(color: selected ? c.textPrimary : c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? LucideIcons.check : icon,
                      size: 20, color: c.textPrimary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTypography.button.copyWith(color: c.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "MEALS · NO MATCHES" state.
class _NoMatches extends ConsumerWidget {
  const _NoMatches({required this.prefs});
  final MealPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(mealPreferencesProvider.notifier);
    final labels = activeFilterLabels(prefs);
    final meal = mealWord(prefs.mealType);
    final body = labels.isEmpty
        ? 'No $meal ideas match your pantry right now. Your inventory is '
            'still here; try another meal type.'
        : 'No $meal ideas match ${labels.join(' + ')}. Your inventory is '
            'still here; try a wider search.';

    Future<void> save(MealPreferences p) async {
      try {
        await notifier.save(p);
      } catch (e) {
        if (context.mounted) showAppSnack(context, friendlyError(e));
      }
    }

    MealPreferences without(String label) {
      final p = prefs;
      if (label == p.matchMode.label && p.matchMode != PantryMatchMode.any) {
        return p.copyWith(matchMode: PantryMatchMode.any);
      }
      if (p.maxMinutes != null && label == timeLabel(p.maxMinutes)) {
        return p.copyWith(clearMaxMinutes: true);
      }
      if (label == p.difficulty?.label) return p.copyWith(clearDifficulty: true);
      if (label == p.dietaryPreference) return p.copyWith(clearDietary: true);
      if (label == p.cuisine) return p.copyWith(clearCuisine: true);
      return p.copyWith(
        excludedIngredients: [
          for (final e in p.excludedIngredients)
            if ('No $e' != label) e,
        ],
      );
    }

    return StateCard(
      overline: 'Meals · no matches',
      icon: LucideIcons.searchX,
      title: 'Nothing fits just yet',
      body: body,
      extra: labels.isEmpty
          ? null
          : ChipWrap(
              children: [
                for (final l in labels)
                  AppChip(
                    label: l,
                    selected: true,
                    onTap: () => save(without(l)),
                  ),
              ],
            ),
      actions: [
        if (prefs.matchMode == PantryMatchMode.availableOnly)
          AppButton(
            label: 'Allow a few missing ingredients',
            onPressed: () =>
                save(prefs.copyWith(matchMode: PantryMatchMode.fewestMissing)),
          ),
        if (prefs.hasActiveFilters)
          AppButton.secondary(
            label: 'Clear meal filters',
            onPressed: () async {
              try {
                await notifier.clearAll();
              } catch (e) {
                if (context.mounted) showAppSnack(context, friendlyError(e));
              }
            },
          ),
      ],
    );
  }
}
