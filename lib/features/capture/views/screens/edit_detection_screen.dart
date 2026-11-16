import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../controllers/capture_controller.dart';
import '../../models/capture_models.dart';
import '../widgets/review_widgets.dart';

enum _Identity { undecided, yes, different }

/// 06 · Edit a detected item, or add a missing one ([detectionId] == null).
/// Nothing is written to the draft until "Confirm item & return to review".
class EditDetectionScreen extends ConsumerStatefulWidget {
  const EditDetectionScreen({super.key, this.detectionId});

  final String? detectionId;

  @override
  ConsumerState<EditDetectionScreen> createState() =>
      _EditDetectionScreenState();
}

class _EditDetectionScreenState extends ConsumerState<EditDetectionScreen> {
  // Cached eagerly: dispose() uses it, and ref is unusable there.
  late final CaptureController _ctrl;

  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _customName = TextEditingController();
  final _notes = TextEditingController();
  final _lowStock = TextEditingController();
  final _nameFocus = FocusNode();

  DetectionDraft? _base;
  bool _isNew = false;
  bool _missing = false;
  Object? _loadError;

  late FoodCategory _category;
  late PantryUnit _unit;
  late FoodState _foodState;
  late StorageLocation _storage;
  late Condition _condition;
  late Condition _freshness;
  DateTime? _dateAdded;
  DateTime? _purchaseDate;
  DateTime? _expiry;
  late DateType _dateType;
  DateTime? _opened;
  String? _photo;
  bool _qtyTouched = false;
  _Identity _identity = _Identity.undecided;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = ref.read(captureControllerProvider.notifier);
    _load();
  }

  Future<void> _load() async {
    try {
      final current = await ref.read(captureControllerProvider.future);
      DetectionDraft? det;
      if (widget.detectionId == null) {
        final draft = current != null &&
                current.status == CaptureDraftStatus.open
            ? current
            : await _ctrl.ensureDraft();
        det = _ctrl.newDetection(
          captureDraftId: draft.id,
          barcode: draft.barcodeValue,
        );
        _isNew = true;
      } else {
        det = _ctrl.detection(widget.detectionId!);
      }
      if (!mounted) return;
      setState(() {
        if (det == null) {
          _missing = true;
        } else {
          _init(det);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  void _init(DetectionDraft d) {
    _base = d;
    _name.text = d.name;
    _qty.text = d.quantity == null ? '' : formatNumber(d.quantity!);
    _customName.text = d.customLocationName ?? '';
    _notes.text = d.notes ?? '';
    _lowStock.text =
        d.lowStockThreshold == null ? '' : formatNumber(d.lowStockThreshold!);
    _category = d.category;
    _unit = d.unit;
    _foodState = d.foodState;
    _storage = d.storage;
    _condition = d.condition;
    _freshness = d.freshness;
    _dateAdded = d.dateAdded;
    _purchaseDate = d.purchaseDate;
    _expiry = d.expiryDate;
    _dateType = d.dateType;
    _opened = d.openedDate;
    _photo = d.photoPath;
  }

  @override
  void dispose() {
    // A photo picked here but never confirmed is not referenced anywhere.
    final p = _photo;
    if (!_saved && p != null && p != _base?.photoPath) {
      _ctrl.discardPhoto(p);
    }
    _name.dispose();
    _qty.dispose();
    _customName.dispose();
    _notes.dispose();
    _lowStock.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _isEstimate =>
      _base?.quantitySource == QuantitySource.visualEstimate && !_qtyTouched;

  Future<void> _pickPhoto() async {
    final pick = await pickReviewPhoto(context, hasPhoto: _photo != null);
    if (pick == null || !mounted) return;
    final previous = _photo;
    try {
      final stored =
          pick.path == null ? null : await _ctrl.importPhoto(pick.path!);
      if (!mounted) return;
      setState(() => _photo = stored);
      // Drop an earlier unconfirmed pick from this session.
      if (previous != null && previous != _base?.photoPath) {
        await _ctrl.discardPhoto(previous);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    }
  }

  Future<void> _confirm() async {
    final base = _base;
    if (base == null || _saving) return;
    final qtyText = _qty.text.trim();
    final qty = parseQuantity(qtyText);
    if (qtyText.isNotEmpty && qty == null) {
      showAppSnack(context, 'Enter the quantity as a number, like 2 or 150.');
      return;
    }
    final lowText = _lowStock.text.trim();
    final low = parseQuantity(lowText);
    if (lowText.isNotEmpty && low == null) {
      showAppSnack(context, 'Enter the low-stock alert as a number.');
      return;
    }
    var source = base.quantitySource;
    if (_qtyTouched && qty != null) {
      source = _unit.kind == UnitKind.count
          ? QuantitySource.userEntered
          : QuantitySource.userMeasured;
    }
    final det = base.copyWith(
      name: _name.text.trim(),
      category: _category,
      quantity: qty,
      clearQuantity: qty == null,
      unit: _unit,
      quantitySource: source,
      foodState: _foodState,
      storage: _storage,
      customLocationName:
          _storage == StorageLocation.custom ? _customName.text.trim() : '',
      isIdentityConfirmed: true,
      condition: _condition,
      freshness: _freshness,
      dateAdded: _dateAdded,
      purchaseDate: _purchaseDate,
      clearPurchaseDate: _purchaseDate == null,
      expiryDate: _expiry,
      clearExpiryDate: _expiry == null,
      dateType: _dateType,
      openedDate: _opened,
      clearOpenedDate: _opened == null,
      lowStockThreshold: low,
      clearLowStock: low == null,
      notes: _notes.text.trim(),
      photoPath: _photo,
      clearPhoto: _photo == null,
    );
    setState(() => _saving = true);
    try {
      await _ctrl.upsertDetection(det);
      _saved = true;
      if (!mounted) return;
      _leave();
    } on ValidationException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.review);
    }
  }

  Future<void> _removeDetection() async {
    final base = _base;
    if (base == null || _saving) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Remove ${base.displayName}?',
      body: 'It won’t be added to your pantry. Nothing else in the review changes.',
      confirmLabel: 'Remove detection',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await _ctrl.removeDetection(base.id);
      if (mounted) _leave();
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _differentFood() {
    setState(() => _identity = _Identity.different);
    final field = _nameFocus.descendants
        .where((n) => n.canRequestFocus)
        .firstOrNull;
    (field ?? _nameFocus).requestFocus();
    _name.selection =
        TextSelection(baseOffset: 0, extentOffset: _name.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.detectionId == null
        ? 'Add a missing item'
        : 'Edit detected item';
    if (_loadError != null) {
      return AppPage(title: title, children: [
        ErrorStateView(error: _loadError!, onRetry: () {
          setState(() => _loadError = null);
          _load();
        }),
      ]);
    }
    if (_missing) {
      return AppPage(title: title, children: [
        StateCard(
          icon: LucideIcons.searchX,
          title: 'This item is no longer in the draft',
          body: 'It may have been removed, merged or split. Return to the review list to continue.',
          actions: [
            AppButton(label: 'Back to review', onPressed: _leave),
          ],
        ),
      ]);
    }
    final base = _base;
    if (base == null) {
      return AppPage(title: title, children: const [LoadingView()]);
    }
    return AppPage(
      title: title,
      subtitle: 'Nothing changes until you confirm.',
      children: _form(base),
    );
  }

  List<Widget> _form(DetectionDraft base) {
    final c = context.colors;
    final uncertain = !base.isIdentityConfirmed;
    final shownName = base.name.trim().isEmpty ? 'this item' : base.name.trim();
    return [
      if (uncertain)
        InfoCallout(
          tone: CalloutTone.warning,
          title: 'Is this ${shownName.toLowerCase()}?',
          body:
              'This identification is uncertain. Check the food or label; change the name if needed.',
        ),
      LabeledField(
        label: 'Item name',
        child: Focus(
          focusNode: _nameFocus,
          skipTraversal: true,
          child: AppTextField(
            controller: _name,
            hint: 'e.g. Spinach',
            textInputAction: TextInputAction.next,
            semanticLabel: 'Item name',
            onChanged: (_) {
              if (uncertain && _identity != _Identity.different) {
                setState(() => _identity = _Identity.different);
              }
            },
          ),
        ),
      ),
      if (uncertain)
        ChipWrap(children: [
          AppChip(
            label: 'Yes, ${shownName.toLowerCase()}',
            selected: _identity == _Identity.yes,
            onTap: () => setState(() {
              _identity = _Identity.yes;
              _name.text = base.name;
            }),
          ),
          AppChip(
            label: 'Different food',
            selected: _identity == _Identity.different,
            onTap: _differentFood,
          ),
        ]),
      LabeledField(
        label: 'Category',
        child: AppSelectField<FoodCategory>(
          title: 'Category',
          value: _category,
          options: FoodCategory.values,
          labelOf: (v) => v.label,
          onChanged: (v) => setState(() => _category = v),
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _quantityRow(),
          const SizedBox(height: 7),
          Text(
            _isEstimate
                ? 'Visual estimate — enter your own count or measurement to confirm it.'
                : 'User measured · not an AI weight estimate. Units also support kg, ml, L, pieces, packets, boxes and servings.',
            style: AppTypography.caption
                .copyWith(color: _isEstimate ? c.warning : c.textMuted),
          ),
        ],
      ),
      LabeledField(
        label: 'Food state',
        child: AppSelectField<FoodState>(
          title: 'Food state',
          value: _foodState,
          options: FoodState.values,
          labelOf: (v) => v.label,
          onChanged: (v) => setState(() => _foodState = v),
        ),
      ),
      LabeledField(
        label: 'Storage location',
        child: AppSelectField<StorageLocation>(
          title: 'Storage location',
          value: _storage,
          options: StorageLocation.values,
          labelOf: (v) => v.label,
          onChanged: (v) => setState(() => _storage = v),
        ),
      ),
      if (_storage == StorageLocation.custom)
        LabeledField(
          label: 'Custom location name',
          child: AppTextField(
            controller: _customName,
            hint: 'e.g. Garage shelf',
            semanticLabel: 'Custom location name',
          ),
        ),
      LabeledField(
        label: 'Quality / condition',
        helper: 'A photo cannot establish food safety.',
        child: AppSelectField<Condition>(
          title: 'Quality / condition',
          value: _condition,
          options: Condition.values,
          labelOf: (v) => v.label,
          onChanged: (v) => setState(() => _condition = v),
        ),
      ),
      LabeledField(
        label: 'Freshness',
        child: AppSelectField<Condition>(
          title: 'Freshness',
          value: _freshness,
          options: Condition.values,
          labelOf: (v) => v.label,
          onChanged: (v) => setState(() => _freshness = v),
        ),
      ),
      LabeledField(
        label: 'Date added',
        child: AppDateField(
          label: 'Date added',
          value: _dateAdded,
          onChanged: (v) => setState(() => _dateAdded = v),
        ),
      ),
      LabeledField(
        label: 'Purchase date',
        child: AppDateField(
          label: 'Purchase date',
          value: _purchaseDate,
          onChanged: (v) => setState(() => _purchaseDate = v),
        ),
      ),
      LabeledField(
        label: 'Date type',
        child: AppSelectField<DateType>(
          title: 'Date type',
          value: _dateType,
          options: DateType.values,
          labelOf: (v) => v.label,
          onChanged: (v) => setState(() => _dateType = v),
        ),
      ),
      LabeledField(
        label: 'Expiry / best-before',
        helper: 'Enter only from your own information or a product label.',
        child: AppDateField(
          label: 'Expiry or best-before date',
          value: _expiry,
          onChanged: (v) => setState(() => _expiry = v),
        ),
      ),
      LabeledField(
        label: 'Opened / prepared date',
        child: AppDateField(
          label: 'Opened or prepared date',
          value: _opened,
          onChanged: (v) => setState(() => _opened = v),
        ),
      ),
      LabeledField(
        label: 'Notes',
        child: AppTextField(
          controller: _notes,
          hint: 'Add your own notes',
          minLines: 2,
          maxLines: 5,
          keyboardType: TextInputType.multiline,
          semanticLabel: 'Notes',
        ),
      ),
      LabeledField(
        label: 'Low-stock alert',
        helper: 'Optional · in ${_unit.dbValue}. Leave empty to turn the alert off.',
        child: AppTextField(
          controller: _lowStock,
          hint: 'Off',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: quantityInputFormatters,
          semanticLabel: 'Low-stock alert threshold',
        ),
      ),
      if (_photo != null)
        GestureDetector(
          onTap: () => showReviewPhotoViewer(context, _photo!),
          child: FoodImage(path: _photo, height: 140, semanticLabel: 'Item photo'),
        ),
      AppButton.secondary(
        label: _photo == null ? 'Add an item photo' : 'Replace / remove item photo',
        icon: _photo == null ? LucideIcons.imagePlus : LucideIcons.image,
        onPressed: _saving ? null : _pickPhoto,
      ),
      AppButton(
        label: 'Confirm item & return to review',
        icon: LucideIcons.check,
        loading: _saving,
        onPressed: _confirm,
      ),
      if (!_isNew)
        AppButton.danger(
          label: 'Remove detection',
          onPressed: _saving ? null : _removeDetection,
        ),
    ];
  }

  Widget _quantityRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: LabeledField(
            label: 'Quantity',
            child: AppTextField(
              controller: _qty,
              hint: 'Required',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: quantityInputFormatters,
              semanticLabel: 'Quantity',
              onChanged: (_) {
                if (!_qtyTouched) setState(() => _qtyTouched = true);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LabeledField(
            label: 'Unit',
            child: AppSelectField<PantryUnit>(
              title: 'Unit',
              value: _unit,
              options: PantryUnit.selectable,
              labelOf: (u) => u.dbValue,
              onChanged: (u) => setState(() {
                _unit = u;
                _qtyTouched = true;
              }),
            ),
          ),
        ),
      ],
    );
  }
}
