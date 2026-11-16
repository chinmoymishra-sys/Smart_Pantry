import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/pantry_item.dart';
import '../widgets/inventory_widgets.dart';

/// Consume an amount or replace the measured balance. Shows a preview and
/// changes nothing until the confirm button.
class QuantityScreen extends StatelessWidget {
  const QuantityScreen({
    super.key,
    required this.itemId,
    this.startInSetMode = false,
  });

  final String itemId;
  final bool startInSetMode;

  @override
  Widget build(BuildContext context) => ItemScope(
        itemId: itemId,
        builder: (context, item) =>
            _QuantityView(item: item, startInSetMode: startInSetMode),
      );
}

enum _Mode { consume, set }

class _QuantityView extends ConsumerStatefulWidget {
  const _QuantityView({required this.item, required this.startInSetMode});

  final PantryItem item;
  final bool startInSetMode;

  @override
  ConsumerState<_QuantityView> createState() => _QuantityViewState();
}

class _QuantityViewState extends ConsumerState<_QuantityView> {
  late _Mode _mode = widget.startInSetMode ? _Mode.set : _Mode.consume;
  late PantryUnit _unit = widget.item.unit;
  late double _amount = _initialAmount(_mode);
  bool _saving = false;

  PantryItem get _item => widget.item;

  static double _stepFor(PantryUnit u) => switch (u) {
        PantryUnit.g || PantryUnit.ml => 10,
        PantryUnit.kg || PantryUnit.l => 0.1,
        _ => 1,
      };

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;

  double _initialAmount(_Mode m) {
    if (m == _Mode.set) return _item.quantity;
    final step = _stepFor(_item.unit);
    return _item.quantity < step ? _item.quantity : step;
  }

  void _setMode(_Mode m) {
    if (m == _mode) return;
    setState(() {
      _mode = m;
      _unit = _item.unit;
      _amount = _initialAmount(m);
    });
  }

  void _changeUnit(PantryUnit u) {
    setState(() {
      final converted = tryConvertQuantity(_amount, _unit, u);
      if (converted != null) _amount = _round(converted);
      _unit = u;
    });
  }

  void _step(int dir) {
    final next = _round(_amount + dir * _stepFor(_unit));
    setState(() => _amount = next < 0 ? 0 : next);
  }

  Future<void> _typeAmount() async {
    final v = await showAmountDialog(
      context,
      title: _mode == _Mode.consume ? 'Amount used' : 'New quantity',
      initial: _amount,
      unit: _unit,
    );
    if (v != null && mounted) setState(() => _amount = _round(v));
  }

  /// Available stock in the selected unit, or null if not comparable.
  double? get _available => tryConvertQuantity(_item.quantity, _item.unit, _unit);

  String? get _error {
    if (_mode == _Mode.consume) {
      if (_amount <= 0) return 'Enter an amount above 0 to record use.';
      final avail = _available;
      if (avail == null) return 'Choose a unit compatible with ${_item.unit.label}.';
      if (_amount > avail + 1e-9) {
        return 'That’s more than the ${_item.quantityLabel} available.';
      }
    } else if (_amount < 0) {
      return 'Quantity can’t be negative.';
    }
    return null;
  }

  Future<void> _confirm() async {
    if (_saving || _error != null) return;
    setState(() => _saving = true);
    final ctrl = ref.read(inventoryProvider.notifier);
    final name = _item.name;
    try {
      final String msg;
      if (_mode == _Mode.consume) {
        final updated = await ctrl.consume(_item.id, _amount, _unit);
        msg = 'Used ${formatQuantity(_amount, _unit)} of ${name.toLowerCase()} · '
            '${updated.quantityLabel} left';
      } else {
        final updated = await ctrl.setQuantity(_item.id, _amount, _unit);
        msg = '$name set to ${updated.quantityLabel}';
      }
      if (!mounted) return;
      showAppSnack(context, msg);
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
    final consume = _mode == _Mode.consume;
    final amountLabel = formatQuantity(_amount, _unit);
    final error = _error;
    final units = consume
        ? PantryUnit.selectable
            .where((u) => u.isCompatibleWith(_item.unit))
            .toList()
        : PantryUnit.selectable;
    final unitChangesBalance = !consume && !_unit.isCompatibleWith(_item.unit);

    final List<(String, String)> preview;
    if (consume) {
      final usedInItemUnit = tryConvertQuantity(_amount, _unit, _item.unit);
      final remaining = usedInItemUnit == null
          ? null
          : _item.quantity - usedInItemUnit;
      preview = [
        ('Current amount', _item.quantityLabel),
        ('Use now', '−$amountLabel'),
        (
          'Remaining',
          error != null || remaining == null
              ? '—'
              : formatQuantity(_round(remaining < 0 ? 0 : remaining), _item.unit)
        ),
      ];
    } else {
      preview = [
        ('Current amount', _item.quantityLabel),
        ('New quantity', amountLabel),
      ];
    }

    return AppPage(
      title: consume ? 'How much did you use?' : 'How much is there now?',
      subtitle: '${_item.name} · currently ${_item.quantityLabel} in '
          '${storagePhrase(_item)}',
      children: [
        ChoiceChips<_Mode>(
          options: _Mode.values,
          selected: _mode,
          labelOf: (m) => m == _Mode.consume ? 'Consume' : 'Set quantity',
          onSelected: _saving ? (_) {} : _setMode,
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(consume ? 'AMOUNT USED' : 'NEW QUANTITY',
                  style: AppTypography.body.copyWith(color: c.textMuted)),
              const SizedBox(height: 10),
              Row(
                children: [
                  RoundIconButton(
                    icon: LucideIcons.minus,
                    square: true,
                    semanticLabel: 'Decrease amount',
                    onPressed: _amount <= 0 ? null : () => _step(-1),
                  ),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: '$amountLabel. Tap to type an exact value',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: _typeAmount,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              amountLabel,
                              textAlign: TextAlign.center,
                              style: AppTypography.amount
                                  .copyWith(color: c.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  RoundIconButton(
                    icon: LucideIcons.plus,
                    square: true,
                    semanticLabel: 'Increase amount',
                    onPressed: () => _step(1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Tap the amount to type an exact value.',
                  style: AppTypography.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        LabeledField(
          label: 'Unit',
          helper: unitChangesBalance
              ? 'Changing to ${_unit.label} replaces the balance in that unit; '
                  'the old ${_item.unit.label} amount isn’t converted.'
              : null,
          helperColor: c.warning,
          child: AppSelectField<PantryUnit>(
            value: _unit,
            options: units,
            title: 'Unit',
            labelOf: (u) => u.label,
            onChanged: _changeUnit,
          ),
        ),
        AppCard(
          tone: AppCardTone.muted,
          child: DetailRows(preview),
        ),
        const InfoCallout(
          title: 'Preview only',
          body: 'Nothing has been deducted. Set quantity replaces a measured '
              'balance; Consume records an amount used.',
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              Text(error,
                  style: AppTypography.body.copyWith(color: c.danger)),
              const SizedBox(height: 12),
            ],
            AppButton(
              label: consume
                  ? 'Confirm use of $amountLabel'
                  : 'Set quantity to $amountLabel',
              loading: _saving,
              onPressed: error == null ? _confirm : null,
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              label: 'Cancel · keep ${_item.quantityLabel}',
              onPressed: _saving ? null : () => context.pop(),
            ),
          ],
        ),
      ],
    );
  }
}
