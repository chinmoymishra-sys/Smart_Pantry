import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
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
import '../../../capture/controllers/capture_controller.dart';
import '../../../capture/models/capture_models.dart';
import '../../../history/controllers/history_controller.dart';
import '../../../inventory/controllers/inventory_controller.dart';
import '../../../meals/controllers/meals_controller.dart';
import '../../../meals/models/recipe_match.dart';
import '../../../meals/views/widgets/meal_widgets.dart';

/// Home tab: pantry summary, capture entry points, use-soon reminder,
/// meal inspiration and recent household activity.
class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  bool _uploading = false;

  Future<void> _upload() async {
    if (_uploading) return;
    final notifier = ref.read(captureControllerProvider.notifier);
    final draft = ref.read(captureControllerProvider).value;
    final hasOpenDraft = draft != null &&
        draft.status == CaptureDraftStatus.open &&
        (draft.detections.isNotEmpty || draft.sourcePhotoPath != null);
    if (hasOpenDraft) {
      final n = draft.detections.length;
      final ok = await showConfirmDialog(
        context,
        title: 'Start a new capture?',
        body: 'You have an unsaved capture'
            '${n == 0 ? '' : ' with $n item${n == 1 ? '' : 's'}'}. Starting '
            'again discards it. Nothing in your inventory changes.',
        confirmLabel: 'Discard and choose a photo',
        cancelLabel: 'Keep my capture',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _uploading = true);
    try {
      final XFile? file;
      try {
        file = await ImagePicker().pickImage(source: ImageSource.gallery);
      } on PlatformException catch (e) {
        if (!mounted) return;
        if (e.code.contains('denied') || e.code.contains('access')) {
          context.push(Routes.permission('gallery'));
        } else {
          showAppSnack(context, 'Couldn’t open your photos. Try again or add manually.');
        }
        return;
      }
      if (file == null || !mounted) return;
      if (hasOpenDraft) await notifier.cancel();
      await notifier.start(
        method: CaptureMethod.upload,
        sourcePhotoPath: file.path,
      );
      if (mounted) context.push(Routes.selectedPhoto);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openStorage(StorageLocation s) {
    ref.read(inventoryFilterProvider.notifier).setStorage(s);
    context.go(Routes.inventory);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(inventorySummaryProvider);
    final summary = summaryAsync.value;
    final isEmpty = summary != null && summary.total == 0;

    return AppPage(
      title: 'Smart Pantry',
      subtitle: '${AppDates.weekdayLong(AppDates.today())} · Our household',
      showBack: false,
      children: [
        if (watchHasOpenCooking(ref)) const ContinueCookingCard(),
        if (summaryAsync.hasError && summary == null)
          ErrorStateView(
            error: summaryAsync.error!,
            onRetry: () => ref.invalidate(inventoryProvider),
          )
        else if (summary == null)
          const LoadingView()
        else if (isEmpty)
          StateCard(
            overline: 'Overview · first use',
            icon: LucideIcons.shoppingBasket,
            title: 'A fresh start for your pantry',
            body: '0 items · Fridge 0 · Freezer 0 · Pantry 0. Add your first '
                'food to see storage summaries, date reminders and meal ideas.',
            actions: [
              AppButton(
                label: 'Scan your first groceries',
                icon: LucideIcons.camera,
                onPressed: () => context.push(Routes.camera),
              ),
              AppButton.secondary(
                label: 'Start with manual entry',
                onPressed: () => context.push(Routes.manualAdd),
              ),
            ],
          )
        else
          _SummaryCard(total: summary.total),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Bring your groceries in'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _CaptureButton(
                    icon: LucideIcons.camera,
                    label: 'Camera',
                    onTap: () => context.push(Routes.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CaptureButton(
                    icon: LucideIcons.imageUp,
                    label: 'Upload photo',
                    loading: _uploading,
                    onTap: _upload,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CaptureButton(
                    icon: LucideIcons.scanBarcode,
                    label: 'Barcode / QR',
                    onTap: () => context.push(Routes.barcode),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CaptureButton(
                    icon: LucideIcons.plus,
                    label: 'Add manually',
                    onTap: () => context.push(Routes.manualAdd),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (summary != null && !isEmpty) ...[
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Freezer',
                  value: '${summary.freezer}',
                  onTap: () => _openStorage(StorageLocation.freezer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Fridge',
                  value: '${summary.fridge}',
                  onTap: () => _openStorage(StorageLocation.fridge),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Pantry',
                  value: '${summary.pantry}',
                  onTap: () => _openStorage(StorageLocation.pantry),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                'Use soon',
                action: 'View inventory',
                onAction: () {
                  ref.read(inventoryFilterProvider.notifier).setStorage(null);
                  context.go(Routes.inventory);
                },
              ),
              const SizedBox(height: 12),
              _UseSoonCard(summary: summary),
            ],
          ),
        ],
        const _Inspiration(),
        const _RecentActivity(),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total item${total == 1 ? '' : 's'}.\nAll in one place.',
                  style: AppTypography.hero.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 14),
                Text('Know what you have. Make something good.',
                    style: AppTypography.subtitle.copyWith(color: c.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(LucideIcons.sprout, size: 36, color: c.textPrimary),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.primary,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.buttonRadius,
          side: BorderSide(color: c.primaryBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onTap,
          child: SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  if (loading)
                    SizedBox.square(
                      dimension: 22,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: c.onPrimary),
                      ),
                    )
                  else
                    Icon(icon, size: 22, color: c.onPrimary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(color: c.onPrimary),
                    ),
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

class _UseSoonCard extends StatelessWidget {
  const _UseSoonCard({required this.summary});
  final InventorySummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final low = summary.lowStock.length;
    final lowText = low == 0 ? null : '$low low-stock item${low == 1 ? '' : 's'}';
    if (summary.useSoon.isEmpty) {
      return AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.calendarClock, size: 22, color: c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nothing due in the next ${AppDates.useSoonDays} days',
                      style: AppTypography.title.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    'Based on dates you’ve recorded'
                    '${lowText == null ? '' : ' · $lowText'}',
                    style: AppTypography.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final item = summary.useSoon.first;
    final d = item.expiryDate!;
    final more = summary.useSoon.length - 1;
    return AppCard(
      onTap: () => context.push(Routes.item(item.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.calendarClock, size: 22, color: c.warning),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.name} · ${item.quantityLabel}',
                    style: AppTypography.title.copyWith(color: c.textPrimary)),
                const SizedBox(height: 6),
                Text(
                  '${item.dateType.label} ${AppDates.short(d)} · '
                  '${AppDates.relative(d)}',
                  style: AppTypography.body.copyWith(color: c.warning),
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    'Date entered by you',
                    if (more > 0) '$more more due soon',
                    ?lowText,
                  ].join(' · '),
                  style: AppTypography.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Inspiration extends ConsumerWidget {
  const _Inspiration();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allRecipeMatchesProvider);
    final c = context.colors;
    final previews = <RecipeMatch>[];
    for (final t in MealType.values) {
      for (final m in all.value ?? const <RecipeMatch>[]) {
        if (m.recipe.mealType == t) {
          previews.add(m);
          break;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading('A little inspiration',
            action: 'All meals', onAction: () => context.go(Routes.meals)),
        const SizedBox(height: 12),
        if (all.isLoading && previews.isEmpty)
          const LoadingView(label: 'Finding meal ideas')
        else if (all.hasError && previews.isEmpty)
          ErrorStateView(
              error: all.error!, onRetry: () => ref.invalidate(recipesProvider))
        else if (previews.isEmpty)
          Text('No recipes on this device yet.',
              style: AppTypography.body.copyWith(color: c.textMuted))
        else
          for (var i = 0; i < previews.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _RecipePreview(match: previews[i]),
          ],
      ],
    );
  }
}

class _RecipePreview extends StatelessWidget {
  const _RecipePreview({required this.match});
  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = match.recipe;
    return Semantics(
      button: true,
      label: '${r.mealType.label}, ${r.name}, '
          '${match.availableRequiredCount} of ${match.requiredCount} available',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: AppRadii.cardRadius,
        onTap: () => context.push(Routes.recipe(r.id)),
        child: Row(
          children: [
            FoodImage(path: RecipeImages.thumb(r), width: 92, height: 82),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Overline(r.mealType.label),
                  const SizedBox(height: 4),
                  Text(r.name,
                      style: AppTypography.titleStrong
                          .copyWith(color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    '${match.availableRequiredCount} of ${match.requiredCount} available',
                    style: AppTypography.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 20, color: c.textPrimary),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final activity = ref.watch(activityProvider);
    final latest = (activity.value ?? const <ActivityEntry>[]).take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading('Recently at home',
            action: 'History', onAction: () => context.push(Routes.history)),
        const SizedBox(height: 8),
        if (activity.isLoading && latest.isEmpty)
          const LoadingView()
        else if (latest.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text('Nothing recorded yet.',
                style: AppTypography.subtitle.copyWith(color: c.textMuted)),
          )
        else
          for (final e in latest)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('${e.title} · ${AppDates.activityStamp(e.when)}',
                  style: AppTypography.subtitle.copyWith(color: c.textPrimary)),
            ),
        const SizedBox(height: 10),
        const Footnote('Counts are unique food items, not combined quantities.'),
      ],
    );
  }
}
