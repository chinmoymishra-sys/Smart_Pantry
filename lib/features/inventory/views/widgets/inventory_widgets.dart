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
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/pantry_item.dart';

/// "the fridge" / "Garage shelf" — used in sentences such as
/// "currently in the fridge".
String storagePhrase(PantryItem item) => item.storage == StorageLocation.custom
    ? item.storageLabel
    : 'the ${item.storage.label.toLowerCase()}';

/// Name in running text ("spinach", "olive oil").
String inlineName(PantryItem item) => item.name.trim().toLowerCase();

/// Resolves [itemId] from the loaded inventory and handles the loading,
/// error and missing-item states shared by every item screen.
class ItemScope extends ConsumerWidget {
  const ItemScope({super.key, required this.itemId, required this.builder});

  final String itemId;
  final Widget Function(BuildContext context, PantryItem item) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inventoryProvider);
    if (async.hasValue) {
      final item = ref.watch(pantryItemProvider(itemId));
      if (item == null) return const ItemMissingPage();
      return builder(context, item);
    }
    if (async.hasError) {
      return AppPage(
        title: 'Inventory item',
        children: [
          ErrorStateView(
            error: async.error!,
            onRetry: () => ref.invalidate(inventoryProvider),
          ),
        ],
      );
    }
    return const AppPage(
      title: 'Inventory item',
      children: [LoadingView(label: 'Loading your inventory…')],
    );
  }
}

class ItemMissingPage extends StatelessWidget {
  const ItemMissingPage({super.key});

  @override
  Widget build(BuildContext context) => AppPage(
        title: 'Item not found',
        onBack: () => context.go(Routes.inventory),
        children: [
          StateCard(
            icon: LucideIcons.searchX,
            title: 'This item is no longer in your inventory',
            body: 'It may have been removed on this device. '
                'The rest of your inventory hasn’t changed.',
            actions: [
              AppButton(
                label: 'Back to inventory',
                onPressed: () => context.go(Routes.inventory),
              ),
            ],
          ),
        ],
      );
}

/// Dialog for typing an exact quantity. Returns null when cancelled.
Future<double?> showAmountDialog(
  BuildContext context, {
  required String title,
  required double initial,
  required PantryUnit unit,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _AmountDialog(title: title, initial: initial, unit: unit),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.title,
    required this.initial,
    required this.unit,
  });

  final String title;
  final double initial;
  final PantryUnit unit;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial > 0 ? formatNumber(widget.initial).replaceAll(',', '') : '',
  );
  bool _invalid = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = parseQuantity(_ctrl.text);
    if (v == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Amount in ${widget.unit.label}',
              helper: _invalid ? 'Enter a number of 0 or more.' : null,
              helperColor: c.danger,
              child: AppTextField(
                controller: _ctrl,
                autofocus: true,
                error: _invalid,
                hint: '0',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: quantityInputFormatters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: 20),
            AppButton(label: 'Use this amount', onPressed: _submit),
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
