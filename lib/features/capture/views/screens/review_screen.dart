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
import '../../../inventory/controllers/inventory_controller.dart';
import '../../../inventory/models/pantry_item.dart';
import '../../controllers/capture_controller.dart';
import '../../models/capture_models.dart';
import '../widgets/review_widgets.dart';

/// 05 · Review detected items before saving. Nothing here changes inventory.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _busy = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.scan);
    }
  }

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

  Future<void> _remove(DetectionDraft d) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove ${d.displayName}?',
      body:
          'It won’t be added to your pantry. You can add it back with “Add a missing item”.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(() =>
        ref.read(captureControllerProvider.notifier).removeDetection(d.id));
  }

  Future<void> _discard() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Discard this draft?',
      body:
          'The photo and every item in this review will be deleted. Your pantry won’t change.',
      confirmLabel: 'Discard draft',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(() async {
      await ref.read(captureControllerProvider.notifier).cancel();
      if (mounted) context.go(Routes.scan);
    });
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(captureControllerProvider);
    final pantryCount = ref.watch(inventorySummaryProvider).value?.total;

    return draftAsync.when(
      loading: () => AppPage(
        title: 'Review detected items',
        onBack: _back,
        children: const [LoadingView()],
      ),
      error: (e, _) => AppPage(
        title: 'Review detected items',
        onBack: _back,
        children: [
          ErrorStateView(
            error: e,
            onRetry: () => ref.invalidate(captureControllerProvider),
          ),
        ],
      ),
      data: (draft) {
        if (draft == null) return _noDraft();
        return _content(draft, pantryCount);
      },
    );
  }

  Widget _noDraft() => AppPage(
        title: 'Review detected items',
        onBack: _back,
        children: [
          StateCard(
            icon: LucideIcons.scanSearch,
            title: 'Nothing to review',
            body:
                'There’s no open capture draft. Take a photo, scan a barcode or add an item yourself to start one.',
            actions: [
              AppButton(
                label: 'Go to Scan / Add',
                icon: LucideIcons.camera,
                onPressed: () => context.go(Routes.scan),
              ),
            ],
          ),
        ],
      );

  Widget _content(CaptureDraft draft, int? pantryCount) {
    final c = context.colors;
    final selected = draft.selected;
    final unresolved = draft.unresolved;
    final subtitle = [
      '${selected.length} selected',
      if (pantryCount != null)
        'Your pantry still has $pantryCount ${pantryCount == 1 ? 'item' : 'items'}',
    ].join(' · ');

    final children = <Widget>[
      if (draft.sourcePhotoPath != null)
        GestureDetector(
          onTap: () => showReviewPhotoViewer(context, draft.sourcePhotoPath!),
          child: FoodImage(
            path: draft.sourcePhotoPath,
            height: 152,
            semanticLabel: 'Your capture photo. Tap to view full screen.',
          ),
        ),
      if (draft.detections.isEmpty)
        const InfoCallout(
          title: 'No items to review yet',
          body:
              'Photo recognition isn’t available on this device, so nothing was detected or guessed. Add each item yourself with its name and quantity.',
        )
      else
        const InfoCallout(
          title: 'Estimates, not measurements',
          body:
              'Check names, quantities and storage. Dates are never guessed from appearance.',
        ),
      for (final d in draft.detections)
        _DetectionCard(
          detection: d,
          sourcePhoto: draft.sourcePhotoPath,
          busy: _busy,
          onToggle: () => _run(() => ref
              .read(captureControllerProvider.notifier)
              .toggleSelected(d.id)),
          onEdit: () => context.push(Routes.editDetection(d.id)),
          onSplitMerge: () => context.push(Routes.splitMerge(d.id)),
          onRemove: () => _remove(d),
        ),
      AppButton.secondary(
        label: 'Add a missing item',
        icon: LucideIcons.plus,
        onPressed: () => context.push(Routes.newDetection),
      ),
      if (unresolved.isNotEmpty)
        Text(
          _unresolvedMessage(unresolved.first),
          style: AppTypography.body.copyWith(color: c.warning),
        ),
      _primary(draft),
      Center(
        child: TextAction(
          label: 'Discard this draft',
          danger: true,
          onPressed: _busy ? null : _discard,
        ),
      ),
    ];

    return AppPage(
      title: 'Review detected items',
      subtitle: subtitle,
      onBack: _back,
      children: children,
    );
  }

  String _unresolvedMessage(DetectionDraft u) {
    const tail = 'The save action becomes available after confirmation.';
    if (!u.isIdentityConfirmed) {
      return 'Confirm “${u.displayName}” in Edit before saving. $tail';
    }
    return 'Enter a quantity for “${u.displayName}” in Edit before saving. $tail';
  }

  Widget _primary(CaptureDraft draft) {
    final selected = draft.selected.length;
    final unresolved = draft.unresolved.length;
    if (unresolved > 0) {
      return AppButton(
        label:
            'Confirm $unresolved ${unresolved == 1 ? 'item' : 'items'} to save $selected',
        onPressed: null,
      );
    }
    if (selected == 0) {
      return const AppButton(label: 'Select an item to save', onPressed: null);
    }
    return AppButton(
      label: 'Review $selected ${selected == 1 ? 'item' : 'items'}',
      icon: LucideIcons.arrowRight,
      onPressed: _busy ? null : () => context.push(Routes.confirmAdditions),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({
    required this.detection,
    required this.sourcePhoto,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onSplitMerge,
    required this.onRemove,
  });

  final DetectionDraft detection;
  final String? sourcePhoto;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onSplitMerge;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = detection;
    final photo = d.photoPath ?? sourcePhoto;

    final String identity;
    Color identityColor = c.textMuted;
    if (!d.isIdentityConfirmed) {
      identity = 'Uncertain identity · please confirm';
      identityColor = c.warning;
    } else if (d.suggestedName != null &&
        PantryItem.normalize(d.suggestedName!) == PantryItem.normalize(d.name)) {
      identity = 'Suggested identity · review before saving';
    } else {
      identity = 'Entered by you';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: photo == null
                    ? null
                    : () => showReviewPhotoViewer(context, photo),
                child: photo == null
                    ? Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: c.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(LucideIcons.imageOff,
                            size: 22, color: c.textMuted),
                      )
                    : FoodImage(
                        path: photo,
                        width: 60,
                        height: 60,
                        radius: 14,
                        semanticLabel:
                            'Photo of ${d.name}. Tap to view full screen.',
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  photo == null
                      ? 'No photo for this item'
                      : 'Food preview · check the original photo',
                  style: AppTypography.caption.copyWith(color: c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ReviewCheckbox(
                selected: d.isSelected,
                semanticLabel: 'Include ${d.name} in this save',
                onTap: busy ? null : onToggle,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.displayName.isEmpty ? 'Unnamed item' : d.displayName,
                        style: AppTypography.title
                            .copyWith(color: c.textPrimary)),
                    const SizedBox(height: 2),
                    Text(identity,
                        style:
                            AppTypography.caption.copyWith(color: identityColor)),
                  ],
                ),
              ),
              TextAction(label: 'Edit', onPressed: onEdit, strong: false),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            d.quantityLine,
            style: AppTypography.subtitle.copyWith(
              color: d.hasQuantity ? c.textPrimary : c.warning,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            reviewJoin([d.category.label, d.foodState.label, d.storageLabel]),
            style: AppTypography.body.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 12),
          Text(
            'Quality / safety: ${d.condition.label.toLowerCase()}',
            style: AppTypography.caption.copyWith(color: c.textMuted),
          ),
          Text(d.dateLine,
              style: AppTypography.caption.copyWith(color: c.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              TextAction(
                label: 'Split / merge',
                strong: false,
                onPressed: busy ? null : onSplitMerge,
              ),
              const Spacer(),
              TextAction(
                label: 'Remove',
                danger: true,
                strong: false,
                onPressed: busy ? null : onRemove,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
