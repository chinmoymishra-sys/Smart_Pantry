import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../controllers/meals_controller.dart';
import '../../models/recipe.dart';
import '../widgets/meal_widgets.dart';

const _countWords = [
  'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
  'Nine', 'Ten', 'Eleven', 'Twelve',
];

/// Full numbered method for a recipe.
class RecipeInstructionsScreen extends ConsumerStatefulWidget {
  const RecipeInstructionsScreen({super.key, required this.recipeId});
  final String recipeId;

  @override
  ConsumerState<RecipeInstructionsScreen> createState() =>
      _RecipeInstructionsScreenState();
}

class _RecipeInstructionsScreenState
    extends ConsumerState<RecipeInstructionsScreen> {
  bool _starting = false;

  Future<void> _start(Recipe recipe) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await startCookingFlow(context, ref, recipe, recipe.servings);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  static String _title(Recipe r) {
    final n = r.steps.length;
    final word = n < _countWords.length ? _countWords[n] : '$n';
    final steps = '$word step${n == 1 ? '' : 's'}.';
    final onePan = r.equipment.toLowerCase().startsWith('frying pan');
    return onePan ? 'One pan. $steps' : steps;
  }

  @override
  Widget build(BuildContext context) {
    final recipes = ref.watch(recipesProvider);
    final recipe = ref.watch(recipeProvider(widget.recipeId));
    if (recipe == null) {
      return AppPage(
        title: recipes.isLoading ? 'Instructions' : 'Recipe not found',
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
    final c = context.colors;

    return AppPage(
      title: _title(recipe),
      subtitle: '${recipe.name} · serves ${recipe.servings}',
      children: [
        FoodImage(
          path: RecipeImages.instructions(recipe),
          height: 160,
          semanticLabel: 'Illustrative photo of ${recipe.name}',
        ),
        for (final s in recipe.steps)
          Semantics(
            container: true,
            label: 'Step ${s.stepNumber}',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${s.stepNumber}',
                      style: AppTypography.subtitle
                          .copyWith(color: c.textPrimary, height: 1)),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: AppTypography.title
                              .copyWith(color: c.textPrimary)),
                      if (s.durationLabel != null) ...[
                        const SizedBox(height: 4),
                        Text(s.durationLabel!,
                            style: AppTypography.caption
                                .copyWith(color: c.textPrimary)),
                      ],
                      const SizedBox(height: 6),
                      Text(s.instruction,
                          style: AppTypography.subtitle
                              .copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const InfoCallout(
          title: 'Before you begin',
          body: 'Check your ingredients and their storage history. Follow '
              'package guidance; recorded dates and recipe photos don’t '
              'establish food safety.',
        ),
        AppButton(
          label: 'Start step-by-step cooking',
          loading: _starting,
          onPressed: recipe.steps.isEmpty ? null : () => _start(recipe),
        ),
      ],
    );
  }
}
