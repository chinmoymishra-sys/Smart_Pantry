import 'package:flutter/material.dart';
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
import '../../controllers/cooking_controller.dart';
import '../../models/cooking_models.dart';
import '../widgets/cooking_widgets.dart';

/// "How did it go?" — nothing has been deducted yet.
class CookingCompleteScreen extends ConsumerStatefulWidget {
  const CookingCompleteScreen({super.key});

  @override
  ConsumerState<CookingCompleteScreen> createState() =>
      _CookingCompleteScreenState();
}

class _CookingCompleteScreenState extends ConsumerState<CookingCompleteScreen> {
  bool _busy = false;

  /// Last seen session, so the page doesn't flash an empty state while it
  /// navigates away after the session closes.
  CookingSession? _last;

  CookingController get _ctrl => ref.read(cookingControllerProvider.notifier);

  Future<void> _saveProgress() async {
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

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _ctrl.skipInventoryUpdate();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go(Routes.meals);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content:
                Text('Saved to cooking history. Your pantry is unchanged.')));
    } catch (e) {
      if (mounted) {
        showAppSnack(context, friendlyError(e));
        setState(() => _busy = false);
      }
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.cookResume);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(cookingControllerProvider);
    final live = async.value;
    if (live != null) _last = live;
    final session = live ?? (_busy ? _last : null);

    if (session == null) {
      return AppPage(
        title: 'How did it go?',
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
    final total = recipe?.steps.length ?? session.completedSteps.length;
    final words = session.recipeName.trim().split(RegExp(r'\s+'));
    final dish = words.isEmpty || words.last.isEmpty
        ? 'recipe'
        : words.last.toLowerCase();
    final servings =
        '${session.servings} serving${session.servings == 1 ? '' : 's'}';
    final meta = [
      if (recipe != null) '${recipe.totalMinutes} min estimated',
      session.mealType.label,
      'Prepared today',
    ].join(' · ');

    return AppPage(
      title: 'How did it go?',
      subtitle:
          'All $total step${total == 1 ? '' : 's'} complete · $servings',
      onBack: _back,
      children: [
        FoodImage(
          path: recipe == null ? null : RecipeImages.finished(recipe),
          height: 267,
          semanticLabel: session.recipeName,
        ),
        Text('Did you make the $dish?',
            style: AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
        Text(
          'We’ll help update your pantry with what you actually used. Nothing has been deducted yet.',
          style: AppTypography.title.copyWith(color: c.textMuted),
        ),
        AppCard(
          tone: AppCardTone.muted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.utensils, size: 28, color: c.textPrimary),
              const SizedBox(height: AppSpacing.md),
              Text(session.recipeName,
                  style: AppTypography.title.copyWith(color: c.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              Text(meta,
                  style: AppTypography.body.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        AppButton(
          label: 'Yes · review ingredients used',
          icon: LucideIcons.check,
          onPressed: _busy ? null : () => context.push(Routes.cookDeductions),
        ),
        AppButton.secondary(
          label: 'Not yet · save my progress',
          onPressed: _busy ? null : _saveProgress,
        ),
        AppButton.secondary(
          label: 'Skip inventory update',
          onPressed: _busy ? null : _skip,
        ),
        const Footnote(
            'Skipping leaves all quantities unchanged. You can record actual usage later from cooking history.'),
      ],
    );
  }
}
