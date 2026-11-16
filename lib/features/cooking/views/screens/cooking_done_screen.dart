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
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../inventory/controllers/inventory_controller.dart';
import '../../../inventory/models/pantry_item.dart';
import '../../../meals/controllers/meals_controller.dart';
import '../../controllers/cooking_controller.dart';
import '../../models/cooking_models.dart';

/// Cooking finished and saved to history (Meals branch, nav visible).
class CookingDoneScreen extends ConsumerStatefulWidget {
  const CookingDoneScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<CookingDoneScreen> createState() => _CookingDoneScreenState();
}

class _CookingDoneScreenState extends ConsumerState<CookingDoneScreen> {
  CookingFeedback? _feedback;
  bool _feedbackTouched = false;
  bool _savingFeedback = false;
  bool _savingFavourite = false;
  bool _favouriteSaved = false;

  CookingController get _ctrl => ref.read(cookingControllerProvider.notifier);

  Future<void> _setFeedback(CookingFeedback f) async {
    if (_savingFeedback) return;
    final previous = _feedback;
    setState(() {
      _savingFeedback = true;
      _feedbackTouched = true;
      _feedback = f;
    });
    try {
      await _ctrl.recordFeedback(widget.sessionId, f);
      ref.invalidate(cookingSessionByIdProvider(widget.sessionId));
    } catch (e) {
      if (mounted) {
        setState(() => _feedback = previous);
        showAppSnack(context, friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _savingFeedback = false);
    }
  }

  Future<void> _saveFavourite() async {
    if (_savingFavourite) return;
    setState(() => _savingFavourite = true);
    try {
      await _ctrl.saveToFavourites(widget.sessionId);
      ref.invalidate(cookingSessionByIdProvider(widget.sessionId));
      if (mounted) setState(() => _favouriteSaved = true);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _savingFavourite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync =
        ref.watch(cookingSessionByIdProvider(widget.sessionId));
    final usageAsync = ref.watch(cookingUsageProvider(widget.sessionId));
    const title = 'Made it. Made the most of it.';

    Widget simple(Widget child) =>
        AppPage(title: title, children: [child]);

    if (sessionAsync.hasError) {
      return simple(ErrorStateView(
        error: sessionAsync.error!,
        onRetry: () =>
            ref.invalidate(cookingSessionByIdProvider(widget.sessionId)),
      ));
    }
    final session = sessionAsync.value;
    if (session == null) {
      if (sessionAsync.isLoading) return simple(const LoadingView());
      return simple(StateCard(
        icon: LucideIcons.searchX,
        title: 'Cooking session not found',
        body:
            'This cooking record isn’t on this device any more. Your pantry is unchanged.',
        actions: [
          AppButton(
            label: 'Back to my pantry',
            onPressed: () => context.go(Routes.inventory),
          ),
        ],
      ));
    }

    final c = context.colors;
    final recipe = ref.watch(recipeProvider(session.recipeId));
    final usage = usageAsync.value ?? const <CookingUsage>[];
    final items = ref.watch(inventoryProvider).value;
    final summary = ref.watch(inventorySummaryProvider).value;
    final pantryUpdated = session.status == CookingStatus.completed;
    final confirmed = usage.where((u) => !u.isSkipped && u.isConfirmed).toList();
    final feedback = _feedbackTouched ? _feedback : session.feedback;
    final favourite = _favouriteSaved || session.isFavoriteSaved;

    String change(CookingUsage u) {
      if (u.isSkipped) return 'skipped';
      final unit = u.itemUnit ?? u.actualUnit ?? u.plannedUnit;
      final before = u.quantityBefore;
      final after = u.quantityAfter;
      if (before == null || after == null) {
        return u.actualQuantity == null
            ? 'used'
            : '${formatQuantity(u.actualQuantity!, u.actualUnit ?? unit)} used';
      }
      return '${formatQuantity(before, unit)} → ${formatQuantity(after, unit)}';
    }

    // Low-stock notes for the items this session used.
    final notes = <String>[];
    if (items != null) {
      for (final u in confirmed) {
        PantryItem? item;
        for (final i in items) {
          if (i.id == u.pantryItemId) item = i;
        }
        if (item == null) continue;
        if (item.isOut) {
          notes.add('${item.name} is now finished.');
        } else if (item.isLowStock) {
          final t = item.lowStockThreshold!;
          final tu = item.lowStockUnit ?? item.unit;
          final tInItem = tryConvertQuantity(t, tu, item.unit);
          final wasLow = tInItem != null &&
              u.quantityBefore != null &&
              u.quantityBefore! <= tInItem + 1e-9;
          notes.add('${item.name} is ${wasLow ? 'still' : 'now'} low '
              '(threshold ${formatQuantity(t, tu)}).');
        }
      }
    }
    final remainLine = summary == null
        ? null
        : [
            '${summary.total} unique item${summary.total == 1 ? '' : 's'} remain',
            'Fridge ${summary.fridge}',
            'Freezer ${summary.freezer}',
            'Pantry ${summary.pantry}',
            if (summary.custom > 0) 'Other ${summary.custom}',
          ].join(' · ');

    final when = session.completedAt ?? session.startedAt;
    final today = AppDates.today();
    final isToday = when.year == today.year &&
        when.month == today.month &&
        when.day == today.day;
    final whenLabel = isToday
        ? 'Today, ${AppDates.time(when)}'
        : '${AppDates.short(when)}, ${AppDates.time(when)}';
    final servings =
        '${session.servings} serving${session.servings == 1 ? '' : 's'}';

    String useLabel(CookingUsage u) {
      final q = u.actualQuantity!;
      final unit = u.actualUnit ?? u.plannedUnit;
      final name = u.ingredientName.toLowerCase();
      if (unit == PantryUnit.pieces) return '${formatNumber(q)} $name';
      return '${formatQuantity(q, unit)} $name';
    }

    final actualUse = confirmed.where((u) => u.actualQuantity != null).toList();

    return AppPage(
      title: title,
      subtitle: '${session.mealType.label} saved to cooking history',
      children: [
        FoodImage(
          path: recipe == null ? null : RecipeImages.success(recipe),
          height: 210,
          semanticLabel: session.recipeName,
        ),
        AppCard(
          tone: AppCardTone.muted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.circleCheck, size: 22, color: c.textPrimary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      pantryUpdated
                          ? '${confirmed.length} deduction${confirmed.length == 1 ? '' : 's'} confirmed'
                          : 'Pantry left unchanged',
                      style: AppTypography.title.copyWith(color: c.textPrimary),
                    ),
                  ),
                ],
              ),
              if (usageAsync.isLoading && usage.isEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const LoadingView(),
              ] else if (usage.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                DetailRows([
                  for (final u in usage) (u.ingredientName, change(u)),
                ]),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                Text('No ingredients were deducted.',
                    style: AppTypography.body.copyWith(color: c.textMuted)),
              ],
            ],
          ),
        ),
        if (remainLine != null || notes.isNotEmpty)
          Text(
            [
              if (remainLine != null) '$remainLine.',
              ...notes,
            ].join('\n'),
            style: AppTypography.body.copyWith(color: c.textMuted),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Would you make it again?'),
            const SizedBox(height: AppSpacing.lg),
            ChipWrap(children: [
              for (final f in CookingFeedback.values)
                AppChip(
                  label: f.label,
                  selected: feedback == f,
                  onTap: _savingFeedback ? null : () => _setFeedback(f),
                ),
            ]),
          ],
        ),
        AppButton.secondary(
          label: favourite ? 'Saved to favourites' : 'Save to favourites',
          icon: LucideIcons.heart,
          loading: _savingFavourite,
          onPressed: favourite || _savingFavourite ? null : _saveFavourite,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Cooking history'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.recipeName,
                      style: AppTypography.titleStrong
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '$whenLabel · $servings · '
                    '${pantryUpdated && confirmed.isNotEmpty ? 'pantry updated' : 'pantry unchanged'}',
                    style: AppTypography.body.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    actualUse.isEmpty
                        ? 'No actual use recorded.'
                        : 'Actual use: ${actualUse.map(useLabel).join(', ')}.',
                    style: AppTypography.body.copyWith(color: c.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
        AppButton(
          label: 'Back to my pantry',
          onPressed: () => context.go(Routes.inventory),
        ),
      ],
    );
  }
}
