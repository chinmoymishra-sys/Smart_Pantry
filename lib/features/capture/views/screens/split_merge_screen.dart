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
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../inventory/models/pantry_item.dart';
import '../../controllers/capture_controller.dart';
import '../../models/capture_models.dart';
import '../widgets/review_widgets.dart';

/// 10 · Merge duplicate detections or split a mixed one. Changes only the
/// draft; nothing is saved to inventory here.
class SplitMergeScreen extends ConsumerStatefulWidget {
  const SplitMergeScreen({super.key, this.focusId});

  final String? focusId;

  @override
  ConsumerState<SplitMergeScreen> createState() => _SplitMergeScreenState();
}

class _SplitPart {
  _SplitPart(this.unit);
  final name = TextEditingController();
  final qty = TextEditingController();
  PantryUnit unit;

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

class _SplitMergeScreenState extends ConsumerState<SplitMergeScreen> {
  final _mergedName = TextEditingController();
  bool _mergedNameEdited = false;
  Set<String>? _mergeIds;
  final List<_SplitPart> _parts = [];
  String? _focusId;
  bool _busy = false;

  @override
  void dispose() {
    _mergedName.dispose();
    for (final p in _parts) {
      p.dispose();
    }
    super.dispose();
  }

  static Set<String> _words(String s) => PantryItem.normalize(s)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length >= 3)
      .toSet();

  static bool _similar(DetectionDraft a, DetectionDraft b) {
    final na = PantryItem.normalize(a.name), nb = PantryItem.normalize(b.name);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb || na.contains(nb) || nb.contains(na)) return true;
    return _words(a.name).intersection(_words(b.name)).isNotEmpty;
  }

  void _initFor(CaptureDraft draft, DetectionDraft focus) {
    if (_focusId == focus.id && _mergeIds != null) return;
    _focusId = focus.id;
    _mergeIds = {
      focus.id,
      for (final d in draft.detections)
        if (d.id != focus.id && _similar(focus, d)) d.id,
    };
    _syncMergedName(draft);
    if (_parts.isEmpty) {
      _parts.addAll([_SplitPart(focus.unit), _SplitPart(focus.unit)]);
    }
  }

  void _syncMergedName(CaptureDraft draft) {
    if (_mergedNameEdited) return;
    final names = draft.detections
        .where((d) => _mergeIds!.contains(d.id))
        .map((d) => d.name.trim())
        .where((n) => n.isNotEmpty)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    _mergedName.text = names.isEmpty ? '' : names.first;
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.review);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showAppSnack(context, done);
      _leave();
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(captureControllerProvider);
    const title = 'One item or two?';
    const subtitle = 'Organize detections without losing your edits.';
    if (async.isLoading && !async.hasValue) {
      return const AppPage(title: title, children: [LoadingView()]);
    }
    final draft = async.value;
    DetectionDraft? focus;
    if (draft != null && draft.detections.isNotEmpty) {
      focus = draft.detections.firstWhere(
        (d) => d.id == (_focusId ?? widget.focusId),
        orElse: () => draft.detections.first,
      );
    }
    if (draft == null || focus == null) {
      return AppPage(
        title: title,
        subtitle: subtitle,
        onBack: _leave,
        children: [
          StateCard(
            icon: LucideIcons.searchX,
            title: 'No detections to organize',
            body: 'Add items to your review first, then merge or split them here.',
            actions: [AppButton(label: 'Back to review', onPressed: _leave)],
          ),
        ],
      );
    }
    _initFor(draft, focus);
    return AppPage(
      title: title,
      subtitle: subtitle,
      onBack: _leave,
      children: [
        SectionHeading(
            'Merge duplicate ${_displayName(focus).toLowerCase()}'),
        _mergeCard(draft, focus),
        const InfoCallout(
          title: 'Nothing is saved to inventory here',
          body:
              'Merge keeps one reviewable item. Conflicting dates or units must be resolved before confirming.',
        ),
        const SectionHeading('Split a mixed detection'),
        _splitCard(focus),
        AppButton(
          label: 'Done · return to review',
          onPressed: _busy ? null : _leave,
        ),
      ],
    );
  }

  String _displayName(DetectionDraft d) =>
      d.name.trim().isEmpty ? 'item' : d.name.trim();

  // ---------------------------------------------------------------- merge

  Widget _mergeCard(CaptureDraft draft, DetectionDraft focus) {
    final c = context.colors;
    final ids = _mergeIds!;
    // Keep the focus first so its record (and unit) is the one kept.
    final parts = [
      ...draft.detections.where((d) => d.id == focus.id && ids.contains(d.id)),
      ...draft.detections.where((d) => d.id != focus.id && ids.contains(d.id)),
    ];
    final unit = parts.isEmpty ? focus.unit : parts.first.unit;

    final problems = <String>[];
    final notes = <String>[];
    double? total = 0;
    for (final p in parts) {
      if (!p.hasQuantity) {
        problems.add('Enter a quantity for ${_displayName(p)} in Edit first.');
        total = null;
        continue;
      }
      final conv = tryConvertQuantity(p.quantity!, p.unit, unit);
      if (conv == null) {
        total = null;
      } else if (total != null) {
        total += conv;
      }
    }
    final unitsCompatible =
        parts.every((p) => p.unit.isCompatibleWith(unit));
    if (!unitsCompatible) {
      problems.add(
          'Units can’t be combined (${parts.map((p) => p.unit.dbValue).toSet().join(' and ')}). Edit one so they match.');
    }
    final expiries = parts.map((p) => p.expiryDate).toSet();
    if (expiries.length > 1) {
      problems.add('Dates differ. Edit them to match before merging.');
    }
    if (parts.map((p) => p.storage).toSet().length > 1 ||
        parts.map((p) => p.foodState).toSet().length > 1) {
      problems.add('Storage or food state differs. Edit them to match first.');
    }
    if (problems.isEmpty && parts.length >= 2) {
      final estimate =
          parts.any((p) => p.quantitySource == QuantitySource.visualEstimate);
      final sameUnit = parts.every((p) => p.unit == unit);
      final who = parts.length == 2 ? 'Both amounts' : 'All amounts';
      if (estimate) {
        notes.add(
            'Includes a visual estimate — the merged amount stays an estimate until you edit it.');
      } else {
        notes.add(sameUnit
            ? '$who entered by you, in the same unit.'
            : '$who entered by you; converted to ${unit.dbValue}.');
      }
      final date = parts.first.expiryDate;
      notes.add(date == null
          ? 'Dates are not set.'
          : 'Same date: ${parts.first.dateType.label} ${AppDates.short(date)}.');
    }
    final mergedName = _mergedName.text.trim();
    final valid = parts.length >= 2 && problems.isEmpty && mergedName.isNotEmpty;

    final others = draft.detections;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (others.length < 2)
            Text(
              'This draft has only one detection, so there’s nothing to merge.',
              style: AppTypography.body.copyWith(color: c.textMuted),
            )
          else ...[
            for (final d in others)
              InkWell(
                onTap: _busy
                    ? null
                    : () => setState(() {
                          if (!ids.remove(d.id)) ids.add(d.id);
                          _syncMergedName(draft);
                        }),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    ReviewCheckbox(
                      selected: ids.contains(d.id),
                      size: 22,
                      semanticLabel: 'Include ${_displayName(d)} in the merge',
                      onTap: _busy
                          ? null
                          : () => setState(() {
                                if (!ids.remove(d.id)) ids.add(d.id);
                                _syncMergedName(draft);
                              }),
                    ),
                    Expanded(
                      child: Text(
                        reviewJoin([
                          _displayName(d),
                          if (d.hasQuantity) formatQuantity(d.quantity!, d.unit),
                          d.storageLabel,
                        ]),
                        style: AppTypography.titleStrong
                            .copyWith(color: c.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            for (final p in problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(p,
                    style: AppTypography.body.copyWith(color: c.warning)),
              ),
            if (notes.isNotEmpty)
              Text(notes.join(' '),
                  style: AppTypography.body.copyWith(color: c.textMuted)),
            if (parts.length < 2)
              Text('Select at least two detections to merge.',
                  style: AppTypography.body.copyWith(color: c.textMuted)),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Merged name',
              child: AppTextField(
                controller: _mergedName,
                hint: 'Name for the merged item',
                semanticLabel: 'Merged name',
                onChanged: (_) => setState(() => _mergedNameEdited = true),
              ),
            ),
            const SizedBox(height: 14),
            DetailRows([
              (
                'Combined quantity',
                !unitsCompatible
                    ? 'Units can’t be combined'
                    : total == null || parts.length < 2
                        ? '—'
                        : formatQuantity(total, unit),
              ),
            ]),
            const SizedBox(height: 14),
            AppButton(
              label: 'Merge these ${parts.length} detections',
              loading: _busy,
              onPressed: valid
                  ? () => _run(
                        () => ref
                            .read(captureControllerProvider.notifier)
                            .mergeDetections(
                              ids: parts.map((p) => p.id).toList(),
                              mergedName: mergedName,
                              unit: unit,
                            ),
                        'Merged into one item to review.',
                      )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- split

  Widget _splitCard(DetectionDraft focus) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Example: “${_displayName(focus)}”',
              style: AppTypography.titleStrong.copyWith(color: c.textPrimary)),
          const SizedBox(height: 10),
          Text(
            'Use this if one detection contains different foods. Enter each quantity; we won’t divide it by guesswork.',
            style: AppTypography.body.copyWith(color: c.textMuted),
          ),
          for (var i = 0; i < _parts.length; i++) ...[
            const SizedBox(height: 16),
            if (_parts.length > 1)
              Row(
                children: [
                  Expanded(
                    child: Text('Item ${i + 1}',
                        style: AppTypography.caption
                            .copyWith(color: c.textMuted)),
                  ),
                  if (_parts.length > 2)
                    TextAction(
                      label: 'Remove',
                      danger: true,
                      strong: false,
                      onPressed: _busy
                          ? null
                          : () => setState(() => _parts.removeAt(i).dispose()),
                    ),
                ],
              ),
            LabeledField(
              label: 'Item name',
              child: AppTextField(
                controller: _parts[i].name,
                hint: i == 0 ? 'e.g. Spinach' : 'e.g. Coriander',
                semanticLabel: 'Split item ${i + 1} name',
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'Quantity / unit',
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _parts[i].qty,
                      hint: 'Required',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: quantityInputFormatters,
                      semanticLabel: 'Split item ${i + 1} quantity',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppSelectField<PantryUnit>(
                      title: 'Unit',
                      value: _parts[i].unit,
                      options: PantryUnit.selectable,
                      labelOf: (u) => u.dbValue,
                      onChanged: (u) => setState(() => _parts[i].unit = u),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppButton.secondary(
            label: 'Add another split item',
            icon: LucideIcons.plus,
            onPressed: _busy
                ? null
                : () => setState(() => _parts.add(_SplitPart(focus.unit))),
          ),
          const SizedBox(height: 12),
          AppButton.secondary(
            label: 'Review split items',
            onPressed: _busy ? null : () => _split(focus),
          ),
        ],
      ),
    );
  }

  Future<void> _split(DetectionDraft src) async {
    final ctrl = ref.read(captureControllerProvider.notifier);
    final parts = <DetectionDraft>[];
    for (var i = 0; i < _parts.length; i++) {
      final p = _parts[i];
      final name = p.name.text.trim();
      final qty = parseQuantity(p.qty.text);
      if (name.isEmpty) {
        showAppSnack(context, 'Enter a name for split item ${i + 1}.');
        return;
      }
      if (qty == null || qty <= 0) {
        showAppSnack(context, 'Enter a quantity for “$name”. We won’t divide it for you.');
        return;
      }
      parts.add(ctrl
          .newDetection(
            captureDraftId: src.captureDraftId,
            name: name,
            category: src.category,
            quantity: qty,
            unit: p.unit,
            source: p.unit.kind == UnitKind.count
                ? QuantitySource.userEntered
                : QuantitySource.userMeasured,
            foodState: src.foodState,
            storage: src.storage,
            barcode: src.barcode,
          )
          .copyWith(
            customLocationName: src.customLocationName,
            isIdentityConfirmed: true,
            isSelected: src.isSelected,
            dateAdded: src.dateAdded,
            purchaseDate: src.purchaseDate,
            sortOrder: src.sortOrder,
          ));
    }
    await _run(
      () => ctrl.splitDetection(src.id, parts),
      'Split into ${parts.length} items to review.',
    );
  }
}
