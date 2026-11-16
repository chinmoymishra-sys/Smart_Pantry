import 'package:flutter/material.dart';
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
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../models/pantry_item.dart';
import '../widgets/inventory_widgets.dart';

/// Read-only view of one inventory item with entry points to every
/// lifecycle action.
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) => ItemScope(
        itemId: itemId,
        builder: (context, item) => _ItemDetailView(item: item),
      );
}

class _ItemDetailView extends StatelessWidget {
  const _ItemDetailView({required this.item});

  final PantryItem item;

  String get _quantitySource => switch (item.quantitySource) {
        QuantitySource.userMeasured => 'Weighed and entered by you',
        QuantitySource.userEntered => 'Entered by you',
        QuantitySource.visualEstimate => 'Visual estimate · check it yourself',
      };

  Widget _dateCallout() {
    final date = item.expiryDate;
    if (date == null) {
      return const InfoCallout(
        title: 'No date recorded',
        body: 'Add a use-by or best-before date in Edit all item details if '
            'you have one. Dates are reminders, not safety assessments.',
      );
    }
    final warn = item.isUseSoon || item.isPastDate;
    return InfoCallout(
      tone: warn ? CalloutTone.warning : CalloutTone.neutral,
      icon: warn ? null : LucideIcons.calendarClock,
      title: '${item.dateType.label} ${AppDates.dayMonth(date)} · '
          '${AppDates.relative(date)}',
      body: 'Date entered by you. This is a date reminder, not an assessment '
          'that the food is safe.',
    );
  }

  List<(String, String)> _rows() {
    String date(DateTime? d) => d == null ? 'Not set' : AppDates.long(d);
    final notes = item.notes?.trim();
    final threshold = item.lowStockThreshold;
    return [
      ('Quality / safety', item.condition.label),
      ('Freshness', item.freshness.label),
      ('Purchase date', date(item.purchaseDate)),
      ('Opened / prepared', date(item.openedDate)),
      ('Notes', notes == null || notes.isEmpty ? 'None' : notes),
      (
        'Low-stock alert',
        threshold == null
            ? 'Off'
            : 'Below ${formatQuantity(threshold, item.lowStockUnit ?? item.unit)}'
      ),
      if (item.storage == StorageLocation.custom)
        ('Storage', item.storageLabel),
      if (item.packageContentLabel != null)
        ('Package content', item.packageContentLabel!),
      ('Source', item.sourceType.label),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photo = item.photoPath;
    return AppPage(
      title: item.name,
      subtitle:
          '${item.category.label} · ${item.foodState.label} · ${item.storageLabel}',
      children: [
        if (photo != null && photo.isNotEmpty)
          FoodImage(path: photo, height: 214, semanticLabel: item.name),
        Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 210),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  item.quantityLabel,
                  style: AppTypography.hero.copyWith(
                      fontSize: 38, letterSpacing: -1, color: c.textPrimary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_quantitySource,
                      style: AppTypography.body.copyWith(color: c.textMuted)),
                  Text('Added ${AppDates.long(item.dateAdded)}',
                      style: AppTypography.body.copyWith(color: c.textMuted)),
                ],
              ),
            ),
          ],
        ),
        if (item.isUnavailable)
          const InfoCallout(
            title: 'Marked unavailable',
            body: 'This item stays in your inventory but is excluded from '
                'meal suggestions. Change it in Finish, discard or remove.',
          ),
        if (item.isOut)
          InfoCallout(
            title: 'Out of stock',
            body: 'The balance is 0 ${item.unit.label}. Use Adjust quantity '
                'to record a new amount, or remove the item.',
          ),
        _dateCallout(),
        AppCard(child: DetailRows(_rows())),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Consume / use some',
              icon: LucideIcons.minus,
              onPressed: item.isOut
                  ? null
                  : () => context.push(Routes.itemQuantity(item.id)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'Adjust quantity',
                    onPressed: () => context
                        .push(Routes.itemQuantity(item.id, setMode: true)),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: AppButton.secondary(
                    label: 'Move',
                    icon: LucideIcons.arrowRightLeft,
                    onPressed: () => context.push(Routes.itemMove(item.id)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              label: 'Edit all item details',
              icon: LucideIcons.pencilLine,
              onPressed: () => context.push(Routes.itemEdit(item.id)),
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              label: 'Finish, discard or remove',
              onPressed: () => context.push(Routes.itemLifecycle(item.id)),
            ),
          ],
        ),
        const Footnote(
          'Check smell, texture, packaging and storage history. Follow '
          'official food-safety guidance when unsure.',
        ),
      ],
    );
  }
}
