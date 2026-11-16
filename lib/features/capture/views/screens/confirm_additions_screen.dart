import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/units.dart';
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

/// 06b · Final before/after preview. "Confirm & save" is the only action that
/// writes the reviewed items to inventory (one transaction).
class ConfirmAdditionsScreen extends ConsumerStatefulWidget {
  const ConfirmAdditionsScreen({super.key});

  @override
  ConsumerState<ConfirmAdditionsScreen> createState() =>
      _ConfirmAdditionsScreenState();
}

class _ConfirmAdditionsScreenState
    extends ConsumerState<ConfirmAdditionsScreen> {
  bool _saving = false;

  /// Keeps the last rendered draft so the page doesn't flash an empty state
  /// while navigating away after a successful save.
  CaptureDraft? _lastDraft;
  List<PantryItem>? _lastItems;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await ref.read(captureControllerProvider.notifier).commit();
      ref.read(lastCommitProvider.notifier).set(result);
      if (mounted) context.go(Routes.saved);
    } catch (e) {
      if (mounted) {
        showAppSnack(context,
            '${friendlyError(e)} Nothing was saved — your review is unchanged.');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final draftAsync = ref.watch(captureControllerProvider);
    var items = ref.watch(inventoryProvider).value;
    // Freeze the "before" counts while saving (inventory refreshes on commit).
    if (_saving) {
      items = _lastItems ?? items;
    } else {
      _lastItems = items;
    }
    var draft = draftAsync.value;
    if (draft != null) {
      _lastDraft = draft;
    } else if (_saving) {
      draft = _lastDraft;
    }

    if (draft == null) {
      if (draftAsync.isLoading) {
        return const AppPage(
            title: 'Ready for your pantry', children: [LoadingView()]);
      }
      return AppPage(
        title: 'Ready for your pantry',
        children: [
          StateCard(
            icon: LucideIcons.scanSearch,
            title: 'Nothing to save',
            body: 'There’s no open review. Start a new capture from Scan / Add.',
            actions: [
              AppButton(
                label: 'Go to Scan / Add',
                onPressed: () => context.go(Routes.scan),
              ),
            ],
          ),
        ],
      );
    }
    return _content(draft, items);
  }

  Widget _content(CaptureDraft draft, List<PantryItem>? items) {
    final c = context.colors;
    final selected = draft.selected;
    final ready = selected.where((d) => d.isReadyToSave).length;
    final newOnes = selected.where((d) => d.mergeTargetItemId == null).toList();

    String? targetName(String id) {
      for (final i in items ?? const <PantryItem>[]) {
        if (i.id == id) return i.name;
      }
      return null;
    }

    String dateText(DetectionDraft d) => d.expiryDate == null
        ? 'Expiry not set'
        : '${d.dateType.label} ${AppDates.short(d.expiryDate!)} (your date)';

    final rows = <(String, String)>[];
    if (items != null) {
      final s = InventorySummary.of(items);
      int add(StorageLocation l) => newOnes.where((d) => d.storage == l).length;
      final fridge = s.fridge + add(StorageLocation.fridge);
      final freezer = s.freezer + add(StorageLocation.freezer);
      final pantry = s.pantry + add(StorageLocation.pantry);
      final custom = s.custom + add(StorageLocation.custom);
      rows.addAll([
        ('Before saving', _unique(s.total)),
        ('After saving', _unique(s.total + newOnes.length)),
        (
          'Storage totals',
          reviewJoin([
            'Fridge $fridge',
            'Freezer $freezer',
            'Pantry $pantry',
            if (custom > 0) 'Custom $custom',
          ])
        ),
      ]);
    }

    final n = selected.length;
    return AppPage(
      title: 'Ready for your pantry',
      subtitle: '$ready of $n selected ${n == 1 ? 'item' : 'items'} confirmed',
      children: [
        if (draft.sourcePhotoPath != null)
          FoodImage(
            path: draft.sourcePhotoPath,
            height: 176,
            semanticLabel: 'Your capture photo',
          ),
        const InfoCallout(
          title: 'Reviewed by you',
          body:
              'You confirmed the names, quantities and storage below. Quality and safety remain not assessed.',
        ),
        if (selected.isEmpty)
          const InfoCallout(
            tone: CalloutTone.warning,
            title: 'No items selected',
            body: 'Go back and select at least one item to save.',
          )
        else
          AppCard(
            child: Column(
              children: [
                for (var i = 0; i < selected.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ItemRow(
                    title: reviewJoin([
                      selected[i].name.trim(),
                      if (selected[i].hasQuantity)
                        formatQuantity(selected[i].quantity!, selected[i].unit),
                    ]),
                    meta: selected[i].mergeTargetItemId != null
                        ? reviewJoin([
                            'Adds to existing ${targetName(selected[i].mergeTargetItemId!) ?? selected[i].name.trim()}',
                            dateText(selected[i]),
                          ])
                        : reviewJoin([
                            selected[i].foodState.label,
                            selected[i].storageLabel,
                            dateText(selected[i]),
                          ]),
                    ready: selected[i].isReadyToSave,
                  ),
                ],
              ],
            ),
          ),
        if (rows.isNotEmpty)
          AppCard(tone: AppCardTone.muted, child: DetailRows(rows)),
        AppButton(
          label: 'Confirm & save $n ${n == 1 ? 'item' : 'items'}',
          icon: LucideIcons.check,
          loading: _saving,
          onPressed: draft.canSave ? _save : null,
        ),
        AppButton.secondary(
          label: 'Go back and edit selections',
          onPressed: _saving
              ? null
              : () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(Routes.review);
                  }
                },
        ),
        Footnote(
          'Save is the only action here that adds these items to inventory.',
          color: c.textMuted,
        ),
      ],
    );
  }

  String _unique(int n) => '$n unique ${n == 1 ? 'item' : 'items'}';
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.title, required this.meta, required this.ready});
  final String title;
  final String meta;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ready ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            size: 22, color: ready ? c.textPrimary : c.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.title.copyWith(color: c.textPrimary)),
              const SizedBox(height: 5),
              Text(meta, style: AppTypography.body.copyWith(color: c.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}
