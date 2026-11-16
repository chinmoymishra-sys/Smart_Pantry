import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../meals/controllers/meals_controller.dart';
import '../../../meals/models/recipe.dart';
import '../../../meals/models/recipe_match.dart';
import '../../controllers/cooking_controller.dart';
import '../widgets/cooking_widgets.dart';

/// Ingredients within reach while cooking, plus pause/exit options.
class CookingIngredientsScreen extends ConsumerStatefulWidget {
  const CookingIngredientsScreen({super.key});

  @override
  ConsumerState<CookingIngredientsScreen> createState() =>
      _CookingIngredientsScreenState();
}

class _CookingIngredientsScreenState
    extends ConsumerState<CookingIngredientsScreen> {
  bool _busy = false;

  CookingController get _ctrl => ref.read(cookingControllerProvider.notifier);

  void _returnToStep() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.cookStep);
    }
  }

  Future<void> _pauseAndExit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ctrl.pauseAndExit();
      if (mounted) context.go(Routes.cookResume);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _endSession() async {
    if (_busy) return;
    final ok = await showConfirmDialog(
      context,
      title: 'End session without saving?',
      body:
          'Your cooking progress will be cleared. No ingredients are deducted and your pantry stays unchanged.',
      confirmLabel: 'End session',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await _ctrl.discard();
      if (mounted) context.go(Routes.meals);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(cookingControllerProvider);
    final session = async.value;
    if (session == null) {
      return AppPage(
        title: 'Ingredients',
        children: [
          if (async.isLoading)
            const LoadingView()
          else if (async.hasError)
            ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(cookingControllerProvider),
            )
          else
            const NoCookingSessionCard(),
        ],
      );
    }
    final recipe = ref.watch(recipeProvider(session.recipeId));
    final match = ref.watch(recipeMatchProvider(
        (recipeId: session.recipeId, servings: session.servings)));
    if (recipe == null) {
      return AppPage(
        title: 'Ingredients',
        children: [
          ref.watch(recipesProvider).isLoading
              ? const LoadingView()
              : const MissingRecipeCard(),
        ],
      );
    }

    final total = recipe.steps.length;
    final stepNo = total == 0 ? 1 : session.currentStep.clamp(1, total);
    final step = total == 0 ? null : recipe.steps[stepNo - 1];
    final hasTimer = session.timerRemainingSeconds != null;
    final timerState = !hasTimer
        ? 'no timer'
        : (session.timerRunning ? 'timer running' : 'timer paused');
    final mentionsPan =
        RegExp(r'\bpans?\b', caseSensitive: false).hasMatch(recipe.equipment);

    // Scaled to the session's servings when inventory is available; fall back
    // to the recipe's own quantities scaled locally.
    final factor = session.servings / (recipe.servings == 0 ? 1 : recipe.servings);
    final required = match?.required.map((m) => m.ingredient).toList() ??
        recipe.required.map((i) => i.scaled(factor)).toList();
    final optional = match?.optional ??
        recipe.optional
            .map((i) => IngredientMatch(
                ingredient: i.scaled(factor),
                availability: IngredientAvailability.missing))
            .toList();

    String detail(RecipeIngredient i) => i.preparation == null
        ? i.amountLabel
        : '${i.amountLabel} · ${i.preparation}';

    String optionalLabel(IngredientMatch m) {
      final i = m.ingredient;
      final amount = i.displayQuantity ?? '${i.amountLabel} ${i.name.toLowerCase()}';
      final stocked = m.pantryItem != null &&
          m.availability != IngredientAvailability.missing;
      return stocked
          ? '$amount · in your pantry'
          : '$amount · not in inventory · skip it';
    }

    return AppPage(
      title: mentionsPan ? 'Everything for this pan' : 'Everything for this recipe',
      subtitle:
          'Step $stepNo of $total · ${session.servings} serving${session.servings == 1 ? '' : 's'} · $timerState',
      onBack: _returnToStep,
      children: [
        if (hasTimer && step != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: AppRadii.cardRadius,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.timer, size: 22, color: c.textPrimary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    session.timerRemainingSeconds! <= 0
                        ? '${step.title} · time’s up'
                        : '${step.title} · ${formatClock(session.timerRemainingSeconds!)} remaining',
                    style: AppTypography.title.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Required ingredients'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: required.isEmpty
                  ? Text('No required ingredients.',
                      style: AppTypography.body.copyWith(color: c.textMuted))
                  : DetailRows([
                      for (final i in required) (i.name, detail(i)),
                    ]),
            ),
          ],
        ),
        if (optional.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading('Optional'),
              const SizedBox(height: AppSpacing.md),
              for (var k = 0; k < optional.length; k++) ...[
                if (k > 0) const SizedBox(height: 8),
                Text(optionalLabel(optional[k]),
                    style: AppTypography.title.copyWith(color: c.textPrimary)),
              ],
            ],
          ),
        AppButton(
          label: 'Return to step $stepNo',
          onPressed: _returnToStep,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Need to step away?',
                  style:
                      AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Save your place and pause the in-app timer. Turn off your hob before leaving the kitchen.',
                style: AppTypography.subtitle.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton.secondary(
                label: 'Pause & exit cooking',
                loading: _busy,
                onPressed: _busy ? null : _pauseAndExit,
              ),
              const SizedBox(height: AppSpacing.md),
              const Footnote('No ingredients are deducted when you exit.'),
            ],
          ),
        ),
        AppButton.danger(
          label: 'End session without saving…',
          onPressed: _busy ? null : _endSession,
        ),
      ],
    );
  }
}
