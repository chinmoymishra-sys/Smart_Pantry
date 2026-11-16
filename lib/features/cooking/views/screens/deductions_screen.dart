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
import '../../../inventory/controllers/inventory_controller.dart';
import '../../../meals/controllers/meals_controller.dart';
import '../../../meals/models/recipe_match.dart';
import '../../controllers/cooking_controller.dart';
import '../../models/cooking_models.dart';
import '../widgets/cooking_widgets.dart';

/// "What did you use?" — editable deduction proposals. Inventory changes
/// only when the user taps "Confirm N inventory deductions".
class DeductionsScreen extends ConsumerStatefulWidget {
  const DeductionsScreen({super.key});

  @override
  ConsumerState<DeductionsScreen> createState() => _DeductionsScreenState();
}

class _DeductionsScreenState extends ConsumerState<DeductionsScreen> {
  List<DeductionProposal>? _proposals;
  bool _saving = false;
  CookingSession? _last;

  CookingController get _ctrl => ref.read(cookingControllerProvider.notifier);

  void _update(int index, DeductionProposal p) =>
      setState(() => _proposals![index] = p);

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.cookResume);
    }
  }

  Future<void> _confirm(CookingSession session) async {
    final list = _proposals;
    if (_saving || list == null) return;
    setState(() => _saving = true);
    try {
      final done = await _ctrl.confirmDeductions(list);
      if (!mounted) return;
      context.go(Routes.cookDone(done?.id ?? session.id));
    } catch (e) {
      if (mounted) {
        showAppSnack(context, friendlyError(e));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _finishWithoutUpdate() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _ctrl.skipInventoryUpdate();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go(Routes.meals);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content:
                Text('Saved to cooking history. Your pantry is unchanged.')));
    } catch (e) {
      if (mounted) {
        showAppSnack(context, friendlyError(e));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _edit(int index) async {
    final p = _proposals![index];
    final result = await showModalBottomSheet<(double, PantryUnit)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AmountSheet(proposal: p),
    );
    if (result == null || !mounted) return;
    final (amount, unit) = result;
    if (amount == p.used && unit == p.usedUnit) return;
    _update(index,
        p.copyWith(used: amount, usedUnit: unit, clearPackageNote: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(cookingControllerProvider);
    final live = async.value;
    if (live != null) _last = live;
    final session = live ?? (_saving ? _last : null);

    const title = 'What did you use?';
    const subtitle = 'Proposed deductions · edit before confirming';

    if (session == null) {
      return AppPage(
        title: title,
        children: [
          if (async.isLoading)
            const LoadingView()
          else if (async.hasError)
            ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(cookingControllerProvider),
            )
          else
            const NoCookingSessionCard(),
        ],
      );
    }

    final match = ref.watch(recipeMatchProvider(
        (recipeId: session.recipeId, servings: session.servings)));
    if (_proposals == null) {
      if (match == null) {
        final loading = ref.watch(recipesProvider).isLoading ||
            ref.watch(inventoryProvider).isLoading;
        return AppPage(
          title: title,
          subtitle: subtitle,
          children: [loading ? const LoadingView() : const MissingRecipeCard()],
        );
      }
      // Loaded once; edits live in local state until confirmed.
      _proposals = List.of(_ctrl.proposeDeductions());
    }
    final proposals = _proposals!;

    const callout = InfoCallout(
      title: 'Your inventory hasn’t changed',
      body:
          'Adjust or skip any ingredient. We’ll apply only the amounts you explicitly confirm below.',
    );

    if (proposals.isEmpty) {
      return AppPage(
        title: title,
        subtitle: 'Nothing to deduct',
        onBack: _leave,
        children: [
          callout,
          StateCard(
            icon: LucideIcons.packageCheck,
            title: 'None of these ingredients are stocked',
            body:
                'Nothing in this recipe matches your inventory, so there’s nothing to deduct. You can still save it to cooking history.',
          ),
          AppButton(
            label: 'Finish without updating pantry',
            icon: LucideIcons.check,
            loading: _saving,
            onPressed: _saving ? null : _finishWithoutUpdate,
          ),
          AppButton.secondary(
            label: 'Not now · keep pantry unchanged',
            onPressed: _saving ? null : _leave,
          ),
        ],
      );
    }

    final included = proposals.where((p) => !p.skipped).toList();
    final allValid = proposals.every((p) => p.isValid);
    final n = included.length;

    return AppPage(
      title: title,
      subtitle: subtitle,
      onBack: _leave,
      children: [
        callout,
        for (var i = 0; i < proposals.length; i++)
          _ProposalCard(
            proposal: proposals[i],
            enabled: !_saving,
            onToggleSkip: () => _update(
                i, proposals[i].copyWith(skipped: !proposals[i].skipped)),
            onEdit: () => _edit(i),
          ),
        Text(
          _footnote(match, proposals),
          style: AppTypography.body.copyWith(color: c.textMuted),
        ),
        if (!allValid)
          Footnote('Fix the highlighted amounts or skip them to continue.',
              color: c.danger),
        AppButton(
          label: n == 0
              ? 'Confirm with no deductions'
              : 'Confirm $n inventory deduction${n == 1 ? '' : 's'}',
          icon: LucideIcons.check,
          loading: _saving,
          onPressed: _saving || !allValid ? null : () => _confirm(session),
        ),
        AppButton.secondary(
          label: 'Not now · keep pantry unchanged',
          onPressed: _saving ? null : _leave,
        ),
      ],
    );
  }

  String _footnote(RecipeMatch? match, List<DeductionProposal> proposals) {
    final parts = <String>[];
    if (match != null) {
      final unstocked = match.ingredients
          .where((m) =>
              m.pantryItem == null ||
              m.availability == IngredientAvailability.missing)
          .toList();
      final opt = unstocked
          .where((m) => !m.ingredient.isRequired)
          .map((m) => m.ingredient.name.toLowerCase())
          .toList();
      final req = unstocked
          .where((m) => m.ingredient.isRequired)
          .map((m) => m.ingredient.name)
          .toList();
      if (opt.isNotEmpty) {
        parts.add('Optional ${_join(opt)} ${opt.length == 1 ? 'isn’t' : 'aren’t'} '
            'stocked, so ${opt.length == 1 ? 'it isn’t' : 'they aren’t'} deducted.');
      }
      if (req.isNotEmpty) {
        parts.add('${_join(req)} ${req.length == 1 ? 'isn’t' : 'aren’t'} in '
            'your inventory, so ${req.length == 1 ? 'it isn’t' : 'they aren’t'} deducted.');
      }
    }
    final zero = proposals
        .where((p) => !p.skipped && p.isValid && (p.after ?? 1) <= 1e-9)
        .map((p) => p.itemName)
        .toList();
    if (zero.isEmpty) {
      parts.add('No item will be marked finished with these amounts.');
    } else {
      parts.add('${_join(zero)} will reach 0 and show as finished.');
    }
    return parts.join(' ');
  }

  static String _join(List<String> xs) {
    if (xs.length <= 1) return xs.join();
    return '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.enabled,
    required this.onToggleSkip,
    required this.onEdit,
  });

  final DeductionProposal proposal;
  final bool enabled;
  final VoidCallback onToggleSkip;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = proposal;
    final skipped = p.skipped;
    final fg = skipped ? c.textMuted : c.textPrimary;

    Widget afterLine() {
      if (p.hasUnitProblem) {
        return Text(
          'Can’t compare ${p.usedUnit.dbValue} with ${p.itemUnit.dbValue} — '
          'enter the amount in ${p.itemUnit.dbValue} or skip it.',
          style: AppTypography.body.copyWith(color: c.danger),
        );
      }
      if (p.exceedsStock) {
        return Text(
          'More than you have — correct the amount or skip it',
          style: AppTypography.body.copyWith(color: c.danger),
        );
      }
      final after = p.after ?? p.before;
      return Text(
        'After confirmation: ${formatQuantity(after < 0 ? 0 : after, p.itemUnit)} remaining',
        style: AppTypography.body.copyWith(color: c.textPrimary),
      );
    }

    return AppCard(
      tone: skipped ? AppCardTone.muted : AppCardTone.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  skipped ? LucideIcons.circle : LucideIcons.circleCheck,
                  size: 22,
                  color: fg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.itemName,
                        style: AppTypography.title.copyWith(color: fg)),
                    const SizedBox(height: 2),
                    Text('Before: ${formatQuantity(p.before, p.itemUnit)}',
                        style:
                            AppTypography.caption.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              TextAction(
                label: skipped ? 'Include' : 'Skip',
                fontSize: 12,
                onPressed: enabled ? onToggleSkip : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (skipped)
            Text('Skipped · not deducted',
                style: AppTypography.body.copyWith(color: c.textMuted))
          else ...[
            Text('Actually used · tap to edit',
                style: AppTypography.label.copyWith(color: c.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            AppPickerField(
              value: p.usedLabel,
              trailing: LucideIcons.pencilLine,
              semanticLabel: 'Edit amount of ${p.itemName} used',
              onTap: enabled ? onEdit : null,
            ),
            const SizedBox(height: AppSpacing.md),
            afterLine(),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet: number field + unit chips limited to compatible units.
class _AmountSheet extends StatefulWidget {
  const _AmountSheet({required this.proposal});
  final DeductionProposal proposal;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _ctrl;
  late PantryUnit _unit;
  late final List<PantryUnit> _units;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.proposal;
    _ctrl = TextEditingController(text: formatNumber(p.used).replaceAll(',', ''));
    _unit = p.usedUnit;
    _units = [
      for (final u in PantryUnit.selectable)
        if (u.isCompatibleWith(p.itemUnit)) u,
    ];
    if (!_units.contains(p.plannedUnit) &&
        p.plannedUnit.isCompatibleWith(p.itemUnit)) {
      _units.add(p.plannedUnit);
    }
    if (_units.isEmpty) _units.add(p.itemUnit);
    if (!_units.contains(_unit)) _unit = p.itemUnit;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseQuantity(_ctrl.text);
    if (v == null) {
      setState(() => _error = 'Enter an amount of 0 or more.');
      return;
    }
    Navigator.of(context).pop((v, _unit));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = widget.proposal;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          22, 0, 22, 22 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.itemName} used',
                  style:
                      AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 6),
              Text(
                'Recipe planned ${formatQuantity(p.plannedQuantity, p.plannedUnit)} · '
                'you have ${formatQuantity(p.before, p.itemUnit)}',
                style: AppTypography.subtitle.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              LabeledField(
                label: 'Amount',
                helper: _error,
                helperColor: _error == null ? null : c.danger,
                child: AppTextField(
                  controller: _ctrl,
                  autofocus: true,
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: quantityInputFormatters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  error: _error != null,
                  semanticLabel: 'Amount used',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Unit',
                  style: AppTypography.label.copyWith(color: c.textPrimary)),
              const SizedBox(height: 7),
              ChoiceChips<PantryUnit>(
                options: _units,
                selected: _unit,
                labelOf: (u) => u.dbValue,
                onSelected: (u) => setState(() {
                  _unit = u;
                  _error = null;
                }),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Save amount',
                icon: LucideIcons.check,
                onPressed: _save,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton.secondary(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
