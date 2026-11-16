import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../meals/views/widgets/meal_widgets.dart';
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
import '../../../meals/models/recipe.dart';
import '../../controllers/cooking_controller.dart';
import '../../models/cooking_models.dart';
import '../widgets/cooking_widgets.dart';

/// Focused cooking mode (no bottom navigation). Nothing here changes
/// inventory — exiting saves progress and pauses the in-app timer.
class CookingStepScreen extends ConsumerStatefulWidget {
  const CookingStepScreen({super.key});

  @override
  ConsumerState<CookingStepScreen> createState() => _CookingStepScreenState();
}

class _CookingStepScreenState extends ConsumerState<CookingStepScreen> {
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

  Future<void> _exit() => _run(() async {
        if (_ctrl.session == null) {
          if (mounted) context.go(Routes.meals);
          return;
        }
        await _ctrl.pauseAndExit();
        if (mounted) context.go(Routes.cookResume);
      });

  Future<void> _completeStep() => _run(() async {
        final finished = await _ctrl.completeStepAndNext();
        if (finished && mounted) {
          context.pushReplacement(Routes.cookComplete);
        }
      });

  Future<void> _previous() => _run(_ctrl.previous);

  @override
  Widget build(BuildContext context) {
    // Haptic cue when the countdown reaches zero.
    ref.listen<AsyncValue<CookingSession?>>(cookingControllerProvider,
        (prev, next) {
      final before = prev?.value;
      final after = next.value;
      if (before == null || after == null) return;
      if (before.currentStep != after.currentStep) return;
      if ((before.timerRemainingSeconds ?? 0) > 0 &&
          after.timerRemainingSeconds == 0) {
        HapticFeedback.mediumImpact();
      }
    });

    final async = ref.watch(cookingControllerProvider);
    final session = async.value;
    final recipe =
        session == null ? null : ref.watch(recipeProvider(session.recipeId));
    final recipesLoading = ref.watch(recipesProvider).isLoading;

    Widget simple(List<Widget> children, {String title = 'Cooking'}) =>
        AppPage(title: title, children: children);

    if (async.hasError && session == null) {
      return simple([
        ErrorStateView(
          error: async.error!,
          onRetry: () => ref.invalidate(cookingControllerProvider),
        ),
      ]);
    }
    if (async.isLoading && session == null) {
      return simple(const [LoadingView()]);
    }
    if (session == null) {
      return simple(const [NoCookingSessionCard()]);
    }
    if (recipe == null) {
      return simple([
        recipesLoading ? const LoadingView() : const MissingRecipeCard(),
      ]);
    }
    if (recipe.steps.isEmpty) {
      return simple(const [MissingRecipeCard()]);
    }

    final total = recipe.steps.length;
    final stepNo = session.currentStep.clamp(1, total);
    final step = recipe.steps[stepNo - 1];
    final c = context.colors;
    final isLast = stepNo >= total;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: AppPage(
        title: step.title,
        subtitle: '${recipe.name} · Step $stepNo of $total',
        onBack: _exit,
        children: [
          StepProgress(total: total, completed: session.completedSteps),
          FoodImage(
            path: RecipeImages.cooking(recipe),
            height: 170,
            semanticLabel: recipe.name,
          ),
          Text(step.headline ?? step.instruction,
              style: AppTypography.stepTitle.copyWith(color: c.textPrimary)),
          if (step.headline != null && step.cookingBody.isNotEmpty)
            Text(step.cookingBody,
                style: AppTypography.bodyLarge.copyWith(color: c.textPrimary)),
          if (step.durationSeconds != null)
            _TimerCard(
              step: step,
              session: session,
              onToggle: _ctrl.toggleTimer,
              onRestart: _ctrl.restartTimer,
            ),
          AppButton.secondary(
            label: 'Ingredients & quantities',
            icon: LucideIcons.list,
            onPressed: () => context.push(Routes.cookIngredients),
          ),
          AppButton(
            label: isLast
                ? 'Mark step complete & finish'
                : 'Mark step complete & next',
            icon: LucideIcons.check,
            loading: _busy,
            onPressed: _busy ? null : _completeStep,
          ),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Previous',
                  icon: LucideIcons.arrowLeft,
                  onPressed: stepNo <= 1 || _busy ? null : _previous,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.secondary(
                  label: 'Exit & save progress',
                  onPressed: _busy ? null : _exit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.step,
    required this.session,
    required this.onToggle,
    required this.onRestart,
  });

  final RecipeStep step;
  final CookingSession session;
  final VoidCallback onToggle;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final remaining = session.timerRemainingSeconds ?? step.durationSeconds!;
    final minutes = (step.durationSeconds! / 60).round();
    final timesUp = remaining <= 0;
    final running = session.timerRunning && !timesUp;
    return AppCard(
      tone: AppCardTone.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: timesUp,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatClock(remaining),
                          style:
                              AppTypography.timer.copyWith(color: c.textPrimary)),
                      const SizedBox(height: 3),
                      Text(
                        timesUp
                            ? 'Time’s up — check the pan'
                            : 'remaining · $minutes-minute timer',
                        style: AppTypography.caption.copyWith(
                          color: c.textPrimary,
                          fontWeight:
                              timesUp ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              RoundIconButton(
                icon: running ? LucideIcons.pause : LucideIcons.play,
                semanticLabel: running ? 'Pause timer' : 'Start timer',
                onPressed: timesUp ? null : onToggle,
              ),
            ],
          ),
          if (step.timerNote != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(step.timerNote!,
                style: AppTypography.caption.copyWith(color: c.textMuted)),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton.secondary(
            label: 'Restart timer',
            icon: LucideIcons.rotateCcw,
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }
}
