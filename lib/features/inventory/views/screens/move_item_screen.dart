import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/pantry_item.dart';
import '../widgets/inventory_widgets.dart';

/// Changes storage only. Food state and expiry are never touched.
class MoveItemScreen extends StatelessWidget {
  const MoveItemScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) => ItemScope(
        itemId: itemId,
        builder: (context, item) => _MoveView(item: item),
      );
}

class _MoveView extends ConsumerStatefulWidget {
  const _MoveView({required this.item});

  final PantryItem item;

  @override
  ConsumerState<_MoveView> createState() => _MoveViewState();
}

class _MoveViewState extends ConsumerState<_MoveView> {
  StorageLocation? _dest;
  late final TextEditingController _customName =
      TextEditingController(text: widget.item.customLocationName ?? '');
  bool _saving = false;

  PantryItem get _item => widget.item;

  @override
  void dispose() {
    _customName.dispose();
    super.dispose();
  }

  String get _trimmedName => _customName.text.trim();

  /// A different location is chosen (or a different custom name).
  bool get _isChange {
    final d = _dest;
    if (d == null) return false;
    if (d != StorageLocation.custom) return d != _item.storage;
    if (_trimmedName.isEmpty) return false;
    return _item.storage != StorageLocation.custom ||
        _trimmedName.toLowerCase() !=
            (_item.customLocationName ?? '').trim().toLowerCase();
  }

  String _destLabel(StorageLocation d) =>
      d == StorageLocation.custom ? _trimmedName : d.label.toLowerCase();

  String _optionLabel(StorageLocation loc) {
    final base = loc == StorageLocation.custom ? 'Custom location' : loc.label;
    if (loc != _item.storage) return base;
    if (loc == StorageLocation.custom) {
      return '$base · current (${_item.storageLabel})';
    }
    return '$base · current location';
  }

  String _preview(List<PantryItem> items) {
    final s = InventorySummary.of(items);
    final counts = {
      StorageLocation.fridge: s.fridge,
      StorageLocation.freezer: s.freezer,
      StorageLocation.pantry: s.pantry,
      StorageLocation.custom: s.custom,
    };
    final d = _dest!;
    if (d != _item.storage) {
      counts[_item.storage] = counts[_item.storage]! - 1;
      counts[d] = counts[d]! + 1;
    }
    final parts = [
      'Fridge ${counts[StorageLocation.fridge]}',
      'Freezer ${counts[StorageLocation.freezer]}',
      'Pantry ${counts[StorageLocation.pantry]}',
      if (counts[StorageLocation.custom]! > 0)
        'Custom ${counts[StorageLocation.custom]}',
    ];
    return 'Preview: ${parts.join(' · ')}. Total stays ${s.total} unique '
        '${s.total == 1 ? 'item' : 'items'}.';
  }

  Future<void> _confirm() async {
    final d = _dest;
    if (_saving || d == null || !_isChange) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(inventoryProvider.notifier).move(
            _item.id,
            d,
            customName: d == StorageLocation.custom ? _trimmedName : null,
          );
      if (!mounted) return;
      showAppSnack(context, '${updated.name} moved to ${storagePhrase(updated)}');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = ref.watch(inventoryProvider).value ?? const <PantryItem>[];
    final d = _dest;
    final needsName = d == StorageLocation.custom && _trimmedName.isEmpty;

    return AppPage(
      title: 'A new spot for ${inlineName(_item)}',
      subtitle: '${_item.quantityLabel} · currently in ${storagePhrase(_item)}',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeading('Move to'),
            const SizedBox(height: 20),
            for (final loc in StorageLocation.values) ...[
              OptionTile(
                label: _optionLabel(loc),
                selected: d == loc,
                onTap: () => setState(() => _dest = loc),
              ),
              if (loc != StorageLocation.values.last)
                const SizedBox(height: 20),
            ],
          ],
        ),
        LabeledField(
          label: 'Custom location name (if selected)',
          helper: needsName ? 'Enter a name for the custom location.' : null,
          helperColor: c.danger,
          child: AppTextField(
            controller: _customName,
            hint: 'e.g. Garage shelf',
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {
              if (_trimmedName.isNotEmpty) _dest = StorageLocation.custom;
            }),
          ),
        ),
        const InfoCallout(
          title: 'Storage and state are different',
          body: 'Moving an item won’t automatically mark it frozen or change '
              'its expiry. Review those fields yourself.',
        ),
        Text(
          d != null && _isChange
              ? _preview(items)
              : 'Choose a new location to preview your storage counts.',
          style: AppTypography.body.copyWith(color: c.textMuted),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: d != null && _isChange
                  ? 'Confirm move to ${_destLabel(d)}'
                  : 'Choose a new location',
              loading: _saving,
              onPressed: _isChange ? _confirm : null,
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              label: 'Cancel · keep in ${_item.storage == StorageLocation.custom ? _item.storageLabel : _item.storage.label.toLowerCase()}',
              onPressed: _saving ? null : () => context.pop(),
            ),
          ],
        ),
      ],
    );
  }
}
