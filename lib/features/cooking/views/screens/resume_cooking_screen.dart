import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../meals/views/widgets/meal_widgets.dart';
import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../meals/controllers/meals_controller.dart';
import '../../controllers/cooking_controller.dart';
import '../widgets/cooking_widgets.dart';

/// Paused cooking session (Meals branch, bottom navigation visible).
class ResumeCookingScreen extends ConsumerStatefulWidget {
  const ResumeCookingScreen({super.key});

  @override
  ConsumerState<ResumeCookingScreen> createState() =>
      _ResumeCookingScreenState();
}

class _ResumeCookingScreenState extends ConsumerState<ResumeCookingScreen> {
  bool _busy = false;

  CookingController get _ctrl => ref.read(cookingControllerProvider.notifier);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume() => _run(() async {
        await _ctrl.resume();
        if (mounted) context.push(Routes.cookStep);
      });

  Future<void> _fromBeginning() => _run(() async {
        await _ctrl.restartFromBeginning();
        if (mounted) context.push(Routes.cookStep);
      });

  Future<void> _discard() async {
    if (_busy) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Discard cooking progress?',
      body:
          'Your saved steps and timer will be cleared. No ingredients are deducted and your pantry stays unchanged.',
      confirmLabel: 'Discard progress',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await _ctrl.discard();
      if (mounted) context.go(Routes.meals);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(cookingControllerProvider);
    final session = async.value;
    const title = 'Pick up where you left off';

    if (session == null) {
      return AppPage(
        title: title,
        subtitle: 'Your pantry is unchanged',
        children: [
          if (async.isLoading)
            const LoadingView()
          else if (async.hasError)
            ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(cookingControllerProvider),
            )
          else
            const NoCookingSessionCard(
              title: 'Nothing to resume',
              body:
                  'There’s no saved cooking session. Pick a recipe from Meals to start cooking.',
            ),
        ],
      );
    }

    final recipe = ref.watch(recipeProvider(session.recipeId));
    if (recipe == null) {
      return AppPage(
        title: title,
        children: [
          ref.watch(recipesProvider).isLoading
              ? const LoadingView()
              : const MissingRecipeCard(),
          AppButton.danger(
            label: 'Discard cooking progress…',
            onPressed: _busy ? null : _discard,
          ),
        ],
      );
    }

    final total = recipe.steps.length;
    final stepNo = total == 0 ? 1 : session.currentStep.clamp(1, total);
    final step = total == 0 ? null : recipe.steps[stepNo - 1];
    final done = session.completedSteps.where((s) => s >= 1 && s <= total).length;
    final review = session.status == CookingStatus.awaitingReview;
    final servings =
        '${session.servings} serving${session.servings == 1 ? '' : 's'}';
    final remaining = session.timerRemainingSeconds;

    return AppPage(
      title: title,
      subtitle: review
          ? 'Cooking finished · your pantry is unchanged'
          : 'Cooking paused · your pantry is unchanged',
      children: [
        FoodImage(path: RecipeImages.paused(recipe), height: 240, semanticLabel: recipe.name),
        Text(recipe.name,
            style: AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
        StepProgress(total: total, completed: session.completedSteps),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                review
                    ? 'All $total steps complete · ingredients not yet reviewed'
                    : 'Next: Step $stepNo · ${step?.title ?? ''}',
                style: AppTypography.title.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '$done step${done == 1 ? '' : 's'} completed · $servings',
                style: AppTypography.subtitle.copyWith(color: c.textMuted),
              ),
              if (!review) ...[
                const SizedBox(height: AppSpacing.md),
                DetailRows([
                  remaining == null
                      ? ('Timer', 'No timer on this step')
                      : ('Timer paused at',
                          remaining <= 0
                              ? 'Time’s up'
                              : '${formatClock(remaining)} remaining'),
                ]),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The in-app timer is paused, but food can keep cooking. Check the pan before resuming.',
                  style: AppTypography.body.copyWith(color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
        if (review)
          AppButton(
            label: 'Review ingredients used',
            icon: LucideIcons.check,
            onPressed: _busy ? null : () => context.push(Routes.cookComplete),
          )
        else
          AppButton(
            label: 'Resume step $stepNo',
            icon: LucideIcons.play,
            loading: _busy,
            onPressed: _busy ? null : _resume,
          ),
        AppButton.secondary(
          label: 'View recipe from the beginning',
          onPressed: _busy ? null : _fromBeginning,
        ),
        AppButton.danger(
          label: 'Discard cooking progress…',
          onPressed: _busy ? null : _discard,
        ),
        const InfoCallout(
          title: 'Inventory stays in your control',
          body:
              'Ingredient deductions are proposed only after cooking and need your confirmation.',
        ),
      ],
    );
  }
}
