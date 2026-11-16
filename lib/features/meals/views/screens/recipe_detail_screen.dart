import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../controllers/meals_controller.dart';
import '../../models/meal_preferences.dart';
import '../../models/recipe.dart';
import '../../models/recipe_match.dart';
import '../widgets/meal_widgets.dart';

/// Recipe overview: timings, servings, availability against confirmed
/// inventory, equipment and the way into cooking mode.
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _servings;
  bool _starting = false;
  bool _saving = false;

  Future<void> _start(Recipe recipe, int servings) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await startCookingFlow(context, ref, recipe, servings);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _availableOnly() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(mealPreferencesProvider.notifier);
      final p = ref.read(mealPreferencesProvider).value ?? const MealPreferences();
      await notifier.save(p.copyWith(matchMode: PantryMatchMode.availableOnly));
      if (mounted) context.go(Routes.meals);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    final recipe = ref.watch(recipeProvider(widget.recipeId));
    if (recipe == null) {
      return AppPage(
        title: recipes.isLoading ? 'Recipe' : 'Recipe not found',
        children: [
          if (recipes.isLoading)
            const LoadingView()
          else if (recipes.hasError)
            ErrorStateView(
                error: recipes.error!,
                onRetry: () => ref.invalidate(recipesProvider))
          else
            StateCard(
              icon: LucideIcons.searchX,
              title: 'This recipe isn’t on this device',
              body: 'It may have been removed. Your inventory hasn’t changed.',
              actions: [
                AppButton(
                    label: 'Back to meals',
                    onPressed: () => context.go(Routes.meals)),
              ],
            ),
        ],
      );
    }

    final servings = _servings ?? recipe.servings;
    final match = ref.watch(
        recipeMatchProvider((recipeId: recipe.id, servings: servings)));
    final c = context.colors;

    return AppPage(
      title: recipe.name,
      subtitle: recipe.summary ?? recipe.description,
      children: [
        FoodImage(
          path: RecipeImages.detail(recipe),
          height: 242,
          semanticLabel: 'Illustrative serving of ${recipe.name}',
        ),
        Row(
          children: [
            Expanded(child: _TimeTile(value: '${recipe.prepMinutes} min', label: 'Prep')),
            const SizedBox(width: 12),
            Expanded(child: _TimeTile(value: '${recipe.cookMinutes} min', label: 'Cook')),
            const SizedBox(width: 12),
            Expanded(child: _TimeTile(value: '${recipe.totalMinutes} min', label: 'Total')),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${recipe.difficulty.label} · $servings serving${servings == 1 ? '' : 's'}',
                style: AppTypography.titleStrong.copyWith(color: c.textPrimary),
              ),
            ),
            IconButton(
              tooltip: 'Fewer servings',
              onPressed: servings > 1
                  ? () => setState(() => _servings = servings - 1)
                  : null,
              icon: Icon(LucideIcons.circleMinus,
                  size: 26, color: servings > 1 ? c.textPrimary : c.textMuted),
            ),
            SizedBox(
              width: 28,
              child: Text('$servings',
                  textAlign: TextAlign.center,
                  semanticsLabel: '$servings servings',
                  style: AppTypography.bodyLarge
                      .copyWith(fontSize: 18, color: c.textPrimary)),
            ),
            IconButton(
              tooltip: 'More servings',
              onPressed: servings < 12
                  ? () => setState(() => _servings = servings + 1)
                  : null,
              icon: Icon(LucideIcons.circlePlus,
                  size: 26, color: servings < 12 ? c.textPrimary : c.textMuted),
            ),
          ],
        ),
        if (match == null)
          const LoadingView(label: 'Checking your inventory')
        else
          ..._availability(context, match),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('What you’ll need'),
            const SizedBox(height: 8),
            Text(recipe.equipment,
                style: AppTypography.subtitle.copyWith(color: c.textMuted)),
          ],
        ),
        Column(
          children: [
            AppButton.secondary(
              label:
                  'View ${recipe.steps.length} numbered instruction${recipe.steps.length == 1 ? '' : 's'}',
              icon: LucideIcons.listOrdered,
              onPressed: () =>
                  context.push(Routes.recipeInstructions(recipe.id)),
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Start cooking',
              icon: LucideIcons.utensils,
              loading: _starting,
              onPressed: recipe.steps.isEmpty
                  ? null
                  : () => _start(recipe, servings),
            ),
          ],
        ),
        const Footnote(
          'Timings are practical estimates; adjust to your hob and '
          'ingredients. Photo is an illustrative serving suggestion.',
        ),
      ],
    );
  }

  List<Widget> _availability(BuildContext context, RecipeMatch m) {
    final c = context.colors;
    final r = m.recipe;
    final allIn = m.isFullyAvailable;
    final missing = m.missingRequired;

    // Callout body.
    final parts = <String>[];
    for (final x in m.availableRequired) {
      final item = x.pantryItem;
      if (item != null && item.isUseSoon && item.expiryDate != null) {
        parts.add('Uses your ${item.name.toLowerCase()} due '
            '${AppDates.short(item.expiryDate!)}.');
        break;
      }
    }
    if (!allIn) {
      parts.add('Still needed: ${missing.map(shortfallLabel).join('; ')}.');
    }
    if (m.optional.isNotEmpty) {
      final names = m.optional.map((o) => o.ingredient.name.toLowerCase()).join(', ');
      parts.add('Optional $names ${m.optional.length == 1 ? 'is' : 'are'} not '
          'needed to make this dish.');
    }

    final optionalLine = m.optional
        .map((o) =>
            '${o.ingredient.amountLabel} · ${o.pantryItem != null ? 'in your pantry' : 'not in inventory'}')
        .join('\n');
    final needToBuy = missing.isEmpty
        ? 'None required'
        : missing.map(shortfallLabel).join('; ');

    String haveText(IngredientMatch x) {
      final have = x.haveLabel;
      final base = '${x.ingredient.amountLabel}${have == null ? '' : ' · $have'}';
      return switch (x.availability) {
        IngredientAvailability.insufficient => '$base · not enough',
        IngredientAvailability.unitMismatch => '$base · units differ, check',
        IngredientAvailability.missing => '${x.ingredient.amountLabel} · not in inventory',
        IngredientAvailability.available => base,
      };
    }

    return [
      InfoCallout(
        title: '${m.availableRequiredCount} of ${m.requiredCount} required '
            'ingredients available',
        body: parts.isEmpty ? null : parts.join(' '),
        tone: allIn ? CalloutTone.neutral : CalloutTone.warning,
      ),
      if (!allIn)
        StateCard(
          overline: 'Recipe · required ingredient missing',
          icon: LucideIcons.shoppingBag,
          title: 'Almost there for ${shortRecipeName(r)}',
          body: '${r.name} has ${m.availableRequiredCount} of '
              '${m.requiredCount} required ingredients. '
              '${missing.map((x) => x.ingredient.name).join(', ')} '
              '${missing.length == 1 ? 'is' : 'are'} required, not optional.',
          extra: Column(
            children: [
              FoodImage(path: RecipeImages.missing(r), height: 146),
              const SizedBox(height: 16),
              DetailRows([
                (
                  'Available',
                  m.availableRequired.isEmpty
                      ? 'None yet'
                      : m.availableRequired
                          .map((x) => '${x.ingredient.name} ${plannedAmount(x.ingredient)}')
                          .join(' · ')
                ),
                ('Need to buy', needToBuy),
              ]),
            ],
          ),
          actions: [
            AppButton(
              label: 'See recipes with no missing items',
              loading: _saving,
              onPressed: _availableOnly,
            ),
          ],
        ),
      if (m.availableRequired.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Available'),
            const SizedBox(height: 10),
            IngredientRows([
              for (final x in m.availableRequired) (x.ingredient.name, haveText(x)),
            ]),
          ],
        ),
      if (missing.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Need to buy'),
            const SizedBox(height: 10),
            IngredientRows(
              [for (final x in missing) (x.ingredient.name, haveText(x))],
              valueColor: c.warning,
              labelColor: c.warning,
            ),
          ],
        ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.optional.isNotEmpty) ...[
              const Overline('Optional', muted: true),
              const SizedBox(height: 12),
              Text(optionalLine,
                  style: AppTypography.title.copyWith(color: c.textPrimary)),
              if (r.optionalNote != null) ...[
                const SizedBox(height: 10),
                Text(r.optionalNote!,
                    style: AppTypography.body.copyWith(color: c.textMuted)),
              ],
              const SizedBox(height: 12),
            ],
            Text(
              'NEED TO BUY · $needToBuy',
              style: AppTypography.body
                  .copyWith(color: missing.isEmpty ? c.textPrimary : c.warning),
            ),
          ],
        ),
      ),
    ];
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadii.buttonRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: AppTypography.bodyLarge.copyWith(color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}
