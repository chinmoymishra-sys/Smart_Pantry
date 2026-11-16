import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../history/controllers/history_controller.dart';
import '../../../inventory/controllers/inventory_controller.dart';
import '../../../inventory/models/pantry_item.dart';
import '../../controllers/capture_controller.dart';

/// 11 · Confirmation after an explicit save. Lives in the Scan tab branch.
class InventorySavedScreen extends ConsumerWidget {
  const InventorySavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final result = ref.watch(lastCommitProvider);
    void back() => context.go(Routes.scan);

    final actions = [
      AppButton(
        label: 'View inventory',
        onPressed: () => context.go(Routes.inventory),
      ),
      AppButton.secondary(
        label: 'What can I cook now?',
        onPressed: () => context.go(Routes.meals),
      ),
    ];

    if (result == null) {
      return AppPage(
        title: 'Saved to your pantry.',
        onBack: back,
        children: [
          StateCard(
            icon: LucideIcons.packageCheck,
            title: 'Nothing new to show',
            body:
                'Your latest additions are already in your inventory. Start a new capture from Scan / Add any time.',
            actions: actions,
          ),
        ],
      );
    }

    final items = ref.watch(inventoryProvider).value ?? const <PantryItem>[];
    final byId = {for (final i in items) i.id: i};
    final saved = [
      for (final id in result.itemIds.toSet())
        if (byId[id] != null) byId[id]!,
    ];
    final summary = InventorySummary.of(items);

    String? photo;
    final scanId = result.scanId;
    if (scanId != null) {
      for (final s in ref.watch(scanRecordsProvider).value ?? const []) {
        if (s.id == scanId) photo = s.photoPath;
      }
    }

    final n = result.total;
    final plural = n == 1 ? 'item' : 'items';
    final title = n >= 2 ? 'A good haul, all sorted.' : 'Saved to your pantry.';
    final explanation = n == 1
        ? 'You confirmed the identity and count of this item. '
        : 'You confirmed the identity and count of all $n items. ';

    return AppPage(
      title: title,
      subtitle: 'Review complete · $n confirmed $plural added',
      onBack: back,
      children: [
        Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.check, size: 36, color: c.textPrimary),
            ),
            if (photo != null) ...[
              const SizedBox(height: 18),
              FoodImage(path: photo, height: 204, semanticLabel: 'Your saved scan photo'),
            ],
          ],
        ),
        if (saved.isNotEmpty)
          AppCard(
            child: DetailRows([
              for (final i in saved)
                (i.name, '${formatQuantity(i.quantity, i.unit)} · ${i.storageLabel}'),
            ]),
          ),
        Text(
          '$explanation'
          'Your pantry now has ${summary.total} unique food ${summary.total == 1 ? 'item' : 'items'}.',
          style: AppTypography.subtitle.copyWith(color: c.textMuted),
        ),
        Row(
          children: [
            for (final (i, l) in [
              StorageLocation.freezer,
              StorageLocation.fridge,
              StorageLocation.pantry,
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _StorageTile(
                  label: l.label,
                  count: switch (l) {
                    StorageLocation.freezer => summary.freezer,
                    StorageLocation.fridge => summary.fridge,
                    _ => summary.pantry,
                  },
                ),
              ),
            ],
          ],
        ),
        ...actions,
      ],
    );
  }
}

class _StorageTile extends StatelessWidget {
  const _StorageTile({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: AppRadii.buttonRadius,
      ),
      child: Text(
        '$label  $count',
        textAlign: TextAlign.center,
        style: AppTypography.caption
            .copyWith(color: c.textPrimary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
