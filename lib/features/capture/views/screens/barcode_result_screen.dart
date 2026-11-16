import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../inventory/controllers/inventory_controller.dart';
import '../../../inventory/models/pantry_item.dart';
import '../../controllers/capture_controller.dart';
import '../../models/capture_models.dart';
import '../widgets/acq_capture_actions.dart';

/// 08 · Alternative capture / barcode result. Product details come only from
/// the household's own saved barcode records — never a fabricated catalog.
class BarcodeResultScreen extends ConsumerStatefulWidget {
  const BarcodeResultScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<BarcodeResultScreen> createState() =>
      _BarcodeResultScreenState();
}

class _BarcodeResultScreenState extends ConsumerState<BarcodeResultScreen> {
  bool _loading = true;
  Object? _error;
  BarcodeProduct? _product;

  final _brandCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _pkgQtyCtrl = TextEditingController();
  FoodCategory _category = FoodCategory.other;
  FoodState _state = FoodState.packaged;
  PantryUnit _unit = PantryUnit.packets;
  PantryUnit? _pkgUnit;
  DateTime? _purchaseDate = AppDates.today();
  DateTime? _bestBefore;
  bool _merge = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lookup();
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _qtyCtrl.dispose();
    _pkgQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    try {
      final p = await ref
          .read(captureControllerProvider.notifier)
          .lookupBarcode(widget.code);
      if (!mounted) return;
      setState(() {
        _product = p;
        _loading = false;
        if (p != null) {
          _brandCtrl.text = p.brand ?? '';
          _category = p.category;
          _state = p.foodState;
          _unit = p.unit;
          // One scanned package; the user can change it.
          _qtyCtrl.text = '1';
          _pkgUnit = p.packageSizeUnit;
          if (p.packageSizeQuantity != null) {
            _pkgQtyCtrl.text = formatNumber(p.packageSizeQuantity!);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  double? get _qty => parseQuantity(_qtyCtrl.text);
  double? get _pkgQty => parseQuantity(_pkgQtyCtrl.text);

  bool _compatible(PantryItem it) =>
      _unit.isCompatibleWith(it.unit) ||
      (_pkgUnit != null &&
          _pkgQty != null &&
          _pkgUnit!.isCompatibleWith(it.unit));

  /// The amount being added, expressed in the existing item's unit.
  double? _addedIn(PantryItem it) {
    final q = _qty;
    if (q == null || q <= 0) return null;
    final direct = tryConvertQuantity(q, _unit, it.unit);
    if (direct != null) return direct;
    final pq = _pkgQty;
    if (pq != null && _pkgUnit != null) {
      return tryConvertQuantity(q * pq, _pkgUnit!, it.unit);
    }
    return null;
  }

  PantryItem? _duplicate(List<PantryItem> items) {
    final p = _product;
    if (p == null) return null;
    final key = PantryItem.normalize(p.name);
    for (final it in items) {
      if (it.normalizedName == key && _compatible(it)) return it;
    }
    return null;
  }

  Future<CaptureDraft?> _startDraft() async {
    if (!await acqConfirmFreshStart(context, ref)) return null;
    return ref
        .read(captureControllerProvider.notifier)
        .start(method: CaptureMethod.barcode, barcode: widget.code);
  }

  Future<void> _submit({required bool editAll}) async {
    final p = _product;
    if (p == null || _saving) return;
    final q = _qty;
    if (q == null || q <= 0) {
      showAppSnack(context, 'Enter how much you bought (above zero).');
      return;
    }
    final items = ref.read(inventoryProvider).value ?? const <PantryItem>[];
    final dup = _duplicate(items);
    final merging = _merge && dup != null;

    var quantity = q;
    var unit = _unit;
    if (merging && !_unit.isCompatibleWith(dup.unit)) {
      // Express the purchase in package contents so the merge can add up.
      quantity = q * _pkgQty!;
      unit = _pkgUnit!;
    }

    setState(() => _saving = true);
    try {
      final draft = await _startDraft();
      if (draft == null || !mounted) return;
      final ctrl = ref.read(captureControllerProvider.notifier);
      final brand = _brandCtrl.text.trim();
      var det = ctrl
          .newDetection(
            captureDraftId: draft.id,
            name: p.name,
            category: _category,
            quantity: quantity,
            unit: unit,
            foodState: _state,
            storage: _state == FoodState.frozen
                ? StorageLocation.freezer
                : StorageLocation.pantry,
            barcode: widget.code,
            packageContentQuantity: _pkgUnit == null ? null : _pkgQty,
            packageContentUnit: _pkgQty == null ? null : _pkgUnit,
          )
          .copyWith(
            purchaseDate: _purchaseDate,
            clearPurchaseDate: _purchaseDate == null,
            expiryDate: _bestBefore,
            dateType: DateType.bestBefore,
            notes: brand.isEmpty ? null : 'Brand: $brand',
          );
      if (merging) det = det.copyWith(mergeTargetItemId: dup.id);
      await ctrl.upsertDetection(det);
      if (!mounted) return;
      context.pushReplacement(
        editAll ? Routes.editDetection(det.id) : Routes.review,
      );
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _enterManually() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final d = await _startDraft();
      if (d != null && mounted) context.push(Routes.newDetection);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _takePhoto() async {
    if (!await acqConfirmFreshStart(context, ref)) return;
    if (mounted) context.push(acqCameraFreshRoute);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppPage(
        title: 'Looking up code',
        subtitle: 'Checking your household’s saved products.',
        children: [LoadingView()],
      );
    }
    if (_error != null) {
      final invalid = _error is ValidationException;
      return AppPage(
        title: invalid ? 'Check the code' : 'Lookup didn’t finish',
        children: [
          StateCard(
            overline: 'BARCODE · ${invalid ? 'INVALID CODE' : 'ERROR'}',
            icon: LucideIcons.circleAlert,
            title: invalid
                ? 'That code doesn’t look right'
                : 'We couldn’t check this code',
            body: '${friendlyError(_error!)} Nothing has been added.',
            actions: [
              AppButton(
                label: 'Try scanning again',
                onPressed: () => context.pop(),
              ),
              AppButton.secondary(
                label: 'Add manually',
                onPressed: () => context.pushReplacement(Routes.manualAdd),
              ),
            ],
          ),
        ],
      );
    }
    final p = _product;
    if (p == null) return _notFound();
    return _found(p);
  }

  Widget _notFound() => AppPage(
    title: 'Product not found',
    subtitle: 'Code ${widget.code}',
    children: [
      StateCard(
        overline: 'BARCODE · UNKNOWN PRODUCT',
        icon: LucideIcons.searchX,
        title: 'We couldn’t find this product',
        body:
            'No catalog record for code ${widget.code}. No brand, '
            'nutrition or package size has been filled in.',
        actions: [
          AppButton(
            label: 'Take a food / label photo',
            onPressed: _saving ? null : _takePhoto,
          ),
          AppButton.secondary(
            label: 'Enter product manually',
            loading: _saving,
            onPressed: _enterManually,
          ),
          AppButton.secondary(
            label: 'Try scanning again',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    ],
  );

  Widget _found(BarcodeProduct p) {
    final c = context.colors;
    final items = ref.watch(inventoryProvider).value ?? const <PantryItem>[];
    final dup = _duplicate(items);
    final pkgLine = p.packageSizeQuantity != null && p.packageSizeUnit != null
        ? '${formatQuantity(p.packageSizeQuantity!, p.packageSizeUnit!)} package'
        : null;
    final subLine = [
      if (p.brand?.trim().isNotEmpty ?? false) p.brand!.trim(),
      ?pkgLine,
    ].join(' · ');

    return AppPage(
      title: 'Product found',
      subtitle: 'Review product details before adding.',
      children: [
        AppCard(
          tone: AppCardTone.muted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.packageCheck, size: 26, color: c.textPrimary),
              const SizedBox(height: 14),
              Text(
                p.name,
                style: AppTypography.sectionTitle.copyWith(
                  color: c.textPrimary,
                ),
              ),
              if (subLine.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  subLine,
                  style: AppTypography.title.copyWith(color: c.textPrimary),
                ),
              ],
              const SizedBox(height: 10),
              Footnote(
                'From your household’s saved product records. '
                'Nutrition is not provided. Code ${widget.code}.',
              ),
            ],
          ),
        ),
        LabeledField(
          label: 'Brand',
          child: AppTextField(
            controller: _brandCtrl,
            hint: 'Not recorded',
            semanticLabel: 'Brand',
            textCapitalization: TextCapitalization.words,
          ),
        ),
        LabeledField(
          label: 'Category / state',
          child: Row(
            children: [
              Expanded(
                child: AppSelectField<FoodCategory>(
                  title: 'Category',
                  value: _category,
                  options: FoodCategory.values,
                  labelOf: (v) => v.label,
                  onChanged: (v) => setState(() => _category = v),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppSelectField<FoodState>(
                  title: 'Food state',
                  value: _state,
                  options: FoodState.values,
                  labelOf: (v) => v.label,
                  onChanged: (v) => setState(() => _state = v),
                ),
              ),
            ],
          ),
        ),
        _quantityRow(
          label: 'Purchased',
          controller: _qtyCtrl,
          hint: 'Amount',
          unit: _unit,
          unitOptions: PantryUnit.selectable,
          onUnit: (u) => setState(() => _unit = u ?? _unit),
        ),
        _quantityRow(
          label: 'Package size',
          controller: _pkgQtyCtrl,
          hint: 'Not set',
          unit: _pkgUnit,
          unitOptions: [
            null,
            ...PantryUnit.selectable.where((u) => u.kind != UnitKind.count),
          ],
          onUnit: (u) => setState(() => _pkgUnit = u),
        ),
        LabeledField(
          label: 'Purchase date',
          child: AppDateField(
            value: _purchaseDate,
            suffix: 'you entered',
            label: 'Purchase date',
            onChanged: (d) => setState(() => _purchaseDate = d),
          ),
        ),
        LabeledField(label: 'Best-before date', child: _bestBeforeField()),
        if (dup != null) ...[
          InfoCallout(
            title: '${dup.name} already in your pantry',
            body: _mergeBody(dup),
          ),
        ],
        if (dup != null)
          ChipWrap(
            children: [
              AppChip(
                label: 'Merge',
                selected: _merge,
                onTap: () => setState(() => _merge = true),
              ),
              AppChip(
                label: 'Keep separate',
                selected: !_merge,
                onTap: () => setState(() => _merge = false),
              ),
            ],
          ),
        Column(
          children: [
            AppButton(
              label: 'Review item & duplicate options',
              loading: _saving,
              onPressed: () => _submit(editAll: false),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.secondary(
              label: 'Wrong product? Edit all details',
              onPressed: _saving ? null : () => _submit(editAll: true),
            ),
          ],
        ),
      ],
    );
  }

  String _mergeBody(PantryItem dup) {
    final have = formatQuantity(dup.quantity, dup.unit);
    final added = _addedIn(dup);
    final into = added == null
        ? 'Review a merge'
        : 'Review a merge into ${formatQuantity(dup.quantity + added, dup.unit)}';
    return 'You have $have. $into or keep this package separate. '
        'Nothing has been added.';
  }

  Widget _quantityRow({
    required String label,
    required TextEditingController controller,
    required String hint,
    required PantryUnit? unit,
    required List<PantryUnit?> unitOptions,
    required ValueChanged<PantryUnit?> onUnit,
  }) => LabeledField(
    label: label,
    child: Row(
      children: [
        Expanded(
          child: AppTextField(
            controller: controller,
            hint: hint,
            semanticLabel: label,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: quantityInputFormatters,
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppSelectField<PantryUnit?>(
            title: '$label unit',
            value: unit,
            options: unitOptions,
            labelOf: (u) => u?.label ?? 'No unit',
            onChanged: onUnit,
          ),
        ),
      ],
    ),
  );

  Widget _bestBeforeField() {
    final c = context.colors;
    final v = _bestBefore;
    return Row(
      children: [
        Expanded(
          child: AppPickerField(
            value: v == null
                ? 'Not set · enter from the package'
                : '${AppDates.long(v)} · you entered',
            semanticLabel: 'Best-before date',
            trailing: LucideIcons.calendar,
            onTap: () async {
              final now = AppDates.today();
              final picked = await showDatePicker(
                context: context,
                initialDate: v ?? now,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) setState(() => _bestBefore = picked);
            },
          ),
        ),
        if (v != null) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Clear date',
            onPressed: () => setState(() => _bestBefore = null),
            icon: Icon(LucideIcons.x, size: 20, color: c.textMuted),
          ),
        ],
      ],
    );
  }
}
