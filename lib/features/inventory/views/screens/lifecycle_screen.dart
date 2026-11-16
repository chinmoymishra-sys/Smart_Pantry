import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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

/// Finish, discard, mark unavailable or permanently remove an item.
class LifecycleScreen extends StatelessWidget {
  const LifecycleScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) => ItemScope(
        itemId: itemId,
        builder: (context, item) => _LifecycleView(item: item),
      );
}

enum _Choice { discard, unavailable }

class _LifecycleView extends ConsumerStatefulWidget {
  const _LifecycleView({required this.item});

  final PantryItem item;

  @override
  ConsumerState<_LifecycleView> createState() => _LifecycleViewState();
}

class _LifecycleViewState extends ConsumerState<_LifecycleView> {
  _Choice _choice = _Choice.discard;
  final _reason = TextEditingController();
  bool _saving = false;

  PantryItem get _item => widget.item;
  InventoryController get _ctrl => ref.read(inventoryProvider.notifier);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  /// Runs [action] with the double-submit guard and shared error handling.
  /// Returns true on success.
  Future<bool> _run(Future<void> Function() action) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await action();
      return true;
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    final zero = formatQuantity(0, _item.unit);
    final ok = await showConfirmDialog(
      context,
      title: 'Mark ${inlineName(_item)} as finished?',
      body: '${_item.quantityLabel} → $zero. The item stays in your history '
          'as used.',
      confirmLabel: 'Finished · used it all',
      cancelLabel: 'Keep item',
    );
    if (!ok || !mounted) return;
    final name = _item.name;
    if (await _run(() => _ctrl.markFinished(_item.id)) && mounted) {
      showAppSnack(context, '$name marked as finished');
      context.pop();
    }
  }

  Future<void> _discard() async {
    final reason = _reason.text.trim();
    final qty = _item.quantityLabel;
    final name = _item.name.toLowerCase();
    final done = await _run(() =>
        _ctrl.discard(_item.id, reason: reason.isEmpty ? null : reason));
    if (done && mounted) {
      showAppSnack(context, 'Discarded $qty of $name');
      context.pop();
    }
  }

  Future<void> _toggleUnavailable() async {
    final makeUnavailable = !_item.isUnavailable;
    final name = _item.name;
    final done =
        await _run(() => _ctrl.setUnavailable(_item.id, makeUnavailable));
    if (done && mounted) {
      showAppSnack(
        context,
        makeUnavailable
            ? '$name marked unavailable · excluded from meals'
            : '$name is available for meals again',
      );
      context.pop();
    }
  }

  Future<void> _remove() async {
    final name = inlineName(_item);
    final ok = await showConfirmDialog(
      context,
      title: 'Remove $name from inventory?',
      body: 'This removes the $name record and its item photo. To keep a '
          'usage or waste entry instead, choose Finished or Discard.',
      confirmLabel: 'Remove $name permanently',
      cancelLabel: 'Cancel · keep item',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = _item.id;
    final displayName = _item.name;
    final done = await _run(() => _ctrl.remove(id));
    if (done) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$displayName removed')));
      router.go(Routes.inventory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final zero = formatQuantity(0, _item.unit);

    return AppPage(
      title: 'What happened to it?',
      subtitle: '${_item.name} · ${_item.quantityLabel} · choose an action',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Mark as finished',
                  style: AppTypography.title.copyWith(color: c.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              Text(
                _item.isOut
                    ? 'The balance is already $zero. Its usage history is kept.'
                    : 'Set balance to zero and keep its usage history.',
                style: AppTypography.body.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(
                label: 'Finished · used it all',
                onPressed: _saving || _item.isOut ? null : _finish,
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Discard or mark unavailable',
                  style: AppTypography.title.copyWith(color: c.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Discard records waste. Unavailable excludes the item from '
                'meal suggestions without deleting it.',
                style: AppTypography.body.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: ChoiceChips<_Choice>(
                  options: _Choice.values,
                  selected: _choice,
                  labelOf: (v) =>
                      v == _Choice.discard ? 'Discard' : 'Unavailable',
                  onSelected: (v) => setState(() => _choice = v),
                ),
              ),
            ],
          ),
        ),
        if (_choice == _Choice.discard)
          AppCard(
            tone: AppCardTone.danger,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Discard all ${_item.quantityLabel}?',
                    style: AppTypography.sectionTitle
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: AppSpacing.md),
                LabeledField(
                  label: 'Reason (optional)',
                  child: AppTextField(
                    controller: _reason,
                    hint: 'No longer usable · assessed by me',
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _item.isOut
                      ? 'The remaining amount is already $zero, so there is '
                          'nothing left to discard.'
                      : 'This sets the remaining amount to $zero. Only confirm '
                          'after checking the item yourself.',
                  style: AppTypography.body.copyWith(color: c.danger),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Confirm discard',
                  loading: _saving,
                  onPressed: _item.isOut ? null : _discard,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton.secondary(
                  label: 'Keep item',
                  onPressed: _saving ? null : () => context.pop(),
                ),
              ],
            ),
          )
        else
          AppCard(
            tone: AppCardTone.muted,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _item.isUnavailable
                      ? '${_item.name} is marked unavailable'
                      : 'Mark ${inlineName(_item)} unavailable?',
                  style:
                      AppTypography.sectionTitle.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _item.isUnavailable
                      ? 'It stays in your inventory with ${_item.quantityLabel} '
                          'but is excluded from meal suggestions. Make it '
                          'available to include it again.'
                      : 'It stays in your inventory with ${_item.quantityLabel} '
                          'but is excluded from meal suggestions. Nothing is '
                          'deducted or deleted.',
                  style: AppTypography.body.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: _item.isUnavailable
                      ? 'Mark available again'
                      : 'Mark unavailable',
                  loading: _saving,
                  onPressed: _toggleUnavailable,
                ),
              ],
            ),
          ),
        AppButton.danger(
          label: 'Remove item and its photo…',
          icon: LucideIcons.trash2,
          onPressed: _saving ? null : _remove,
        ),
        const Footnote(
          'Remove asks for a separate final confirmation and deletes the item '
          'record, not just its remaining quantity.',
        ),
      ],
    );
  }
}
