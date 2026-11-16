import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/pantry_item.dart';
import '../widgets/inventory_widgets.dart';

/// Edits descriptive details (names, dates, condition, notes, photo,
/// low-stock alert). Storage and quantity have their own recorded flows.
class EditItemScreen extends StatelessWidget {
  const EditItemScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) => ItemScope(
        itemId: itemId,
        builder: (context, item) => _EditView(item: item),
      );
}

class _EditView extends ConsumerStatefulWidget {
  const _EditView({required this.item});

  final PantryItem item;

  @override
  ConsumerState<_EditView> createState() => _EditViewState();
}

enum _PhotoSource { camera, gallery }

class _EditViewState extends ConsumerState<_EditView> {
  late final PantryItem _original = widget.item;
  late final _name = TextEditingController(text: _original.name);
  late final _notes = TextEditingController(text: _original.notes ?? '');
  late final _lowStock = TextEditingController(text: _initialThreshold());

  late FoodCategory _category = _original.category;
  late FoodState _foodState = _original.foodState;
  late DateTime _dateAdded = _original.dateAdded;
  late DateTime? _purchase = _original.purchaseDate;
  late DateType _dateType = _original.dateType;
  late DateTime? _expiry = _original.expiryDate;
  late DateTime? _opened = _original.openedDate;
  late Condition _condition = _original.condition;
  late Condition _freshness = _original.freshness;

  /// Newly picked (temporary) image; imported only when saving.
  String? _pickedPhoto;
  bool _photoDeleted = false;
  bool _saving = false;
  bool _nameError = false;
  bool _thresholdError = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _lowStock.dispose();
    super.dispose();
  }

  String _initialThreshold() {
    final t = _original.lowStockThreshold;
    if (t == null) return '';
    final v = tryConvertQuantity(
            t, _original.lowStockUnit ?? _original.unit, _original.unit) ??
        t;
    return formatNumber(v).replaceAll(',', '');
  }

  String? get _currentPhoto =>
      _pickedPhoto ?? (_photoDeleted ? null : _original.photoPath);

  Future<void> _pickPhoto() async {
    final source = await showOptionSheet<_PhotoSource>(
      context,
      title: 'Item photo',
      options: _PhotoSource.values,
      labelOf: (s) =>
          s == _PhotoSource.camera ? 'Take a photo' : 'Choose from photos',
    );
    if (source == null || !mounted) return;
    try {
      final file = await ImagePicker().pickImage(
        source: source == _PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      setState(() {
        _pickedPhoto = file.path;
        _photoDeleted = false;
      });
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        source == _PhotoSource.camera
            ? 'The camera isn’t available. Try choosing from your photos.'
            : 'Couldn’t open your photos. Check photo access in settings.',
      );
    }
  }

  void _deletePhoto() => setState(() {
        _pickedPhoto = null;
        _photoDeleted = true;
      });

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    final rawThreshold = _lowStock.text.trim();
    final threshold = rawThreshold.isEmpty ? null : parseQuantity(rawThreshold);
    final thresholdInvalid = rawThreshold.isNotEmpty && threshold == null;
    setState(() {
      _nameError = name.isEmpty;
      _thresholdError = thresholdInvalid;
    });
    if (name.isEmpty) {
      showAppSnack(context, 'Enter a name for this item.');
      return;
    }
    if (thresholdInvalid) {
      showAppSnack(context, 'Enter a low-stock threshold of 0 or more.');
      return;
    }

    setState(() => _saving = true);
    final ctrl = ref.read(inventoryProvider.notifier);
    String? imported;
    try {
      if (_pickedPhoto != null) imported = await ctrl.importPhoto(_pickedPhoto!);
      final notes = _notes.text.trim();
      final clearThreshold = threshold == null || threshold <= 0;
      final updated = widget.item.copyWith(
        name: name,
        category: _category,
        foodState: _foodState,
        dateAdded: _dateAdded,
        purchaseDate: _purchase,
        clearPurchaseDate: _purchase == null,
        dateType: _dateType,
        expiryDate: _expiry,
        clearExpiryDate: _expiry == null,
        openedDate: _opened,
        clearOpenedDate: _opened == null,
        condition: _condition,
        freshness: _freshness,
        notes: notes.isEmpty ? null : notes,
        clearNotes: notes.isEmpty,
        photoPath: imported,
        clearPhoto: imported == null && _photoDeleted,
        lowStockThreshold: clearThreshold ? null : threshold,
        lowStockUnit: clearThreshold ? null : widget.item.unit,
        clearLowStock: clearThreshold,
      );
      await ctrl.updateDetails(updated);
      if (!mounted) return;
      showAppSnack(context, 'Details saved for $name');
      context.pop();
    } catch (e) {
      if (imported != null) {
        try {
          await ctrl.discardImportedPhoto(imported);
        } catch (_) {/* best effort cleanup */}
      }
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photo = _currentPhoto;
    final unit = widget.item.unit.label;

    return AppPage(
      title: 'The details that matter',
      subtitle: '${_original.name} · editable inventory details',
      children: [
        LabeledField(
          label: 'Item name',
          helper: _nameError ? 'A name is required.' : null,
          helperColor: c.danger,
          child: AppTextField(
            controller: _name,
            hint: 'e.g. Spinach',
            error: _nameError,
            textInputAction: TextInputAction.next,
          ),
        ),
        LabeledField(
          label: 'Category',
          child: AppSelectField<FoodCategory>(
            value: _category,
            options: FoodCategory.values,
            title: 'Category',
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _category = v),
          ),
        ),
        LabeledField(
          label: 'Food state',
          child: AppSelectField<FoodState>(
            value: _foodState,
            options: FoodState.values,
            title: 'Food state',
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _foodState = v),
          ),
        ),
        LabeledField(
          label: 'Date added',
          child: AppDateField(
            value: _dateAdded,
            label: 'Date added',
            allowClear: false,
            onChanged: (v) {
              if (v != null) setState(() => _dateAdded = v);
            },
          ),
        ),
        LabeledField(
          label: 'Purchase date (optional)',
          child: AppDateField(
            value: _purchase,
            label: 'Purchase date',
            onChanged: (v) => setState(() => _purchase = v),
          ),
        ),
        LabeledField(
          label: 'Date type',
          child: AppSelectField<DateType>(
            value: _dateType,
            options: DateType.values,
            title: 'Date type',
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _dateType = v),
          ),
        ),
        LabeledField(
          label: 'Expiry / best-before (optional)',
          helper: 'Source: entered by you. Leave blank if unknown.',
          child: AppDateField(
            value: _expiry,
            label: 'Expiry or best-before date',
            onChanged: (v) => setState(() => _expiry = v),
          ),
        ),
        LabeledField(
          label: 'Opened / prepared date (optional)',
          child: AppDateField(
            value: _opened,
            label: 'Opened or prepared date',
            onChanged: (v) => setState(() => _opened = v),
          ),
        ),
        LabeledField(
          label: 'Quality / condition',
          child: AppSelectField<Condition>(
            value: _condition,
            options: Condition.values,
            title: 'Quality / condition',
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _condition = v),
          ),
        ),
        LabeledField(
          label: 'Freshness',
          helper: 'You can record fresh, good, use soon or spoiled / unsafe '
              'after your own assessment. The app cannot assess safety from '
              'a photo.',
          child: AppSelectField<Condition>(
            value: _freshness,
            options: Condition.values,
            title: 'Freshness',
            labelOf: (v) => v.label,
            onChanged: (v) => setState(() => _freshness = v),
          ),
        ),
        LabeledField(
          label: 'Notes',
          child: AppTextField(
            controller: _notes,
            hint: 'Optional notes',
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
          ),
        ),
        if (photo != null && photo.isNotEmpty)
          Row(
            children: [
              FoodImage(
                path: photo,
                width: 90,
                height: 80,
                semanticLabel: 'Item photo',
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton.secondary(
                      label: 'Replace photo',
                      onPressed: _saving ? null : _pickPhoto,
                    ),
                    const SizedBox(height: 8),
                    AppButton.danger(
                      label: 'Delete photo',
                      onPressed: _saving ? null : _deletePhoto,
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          AppButton.secondary(
            label: 'Add a photo',
            icon: LucideIcons.imagePlus,
            onPressed: _saving ? null : _pickPhoto,
          ),
        LabeledField(
          label: 'Low-stock alert (optional)',
          helper: _thresholdError
              ? 'Enter a number in $unit, or leave blank to turn it off.'
              : 'Alert when below this amount, in $unit.',
          helperColor: _thresholdError ? c.danger : null,
          child: AppTextField(
            controller: _lowStock,
            hint: 'Off · set a threshold in $unit',
            error: _thresholdError,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: quantityInputFormatters,
            textInputAction: TextInputAction.done,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Save details',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              label: 'Cancel',
              onPressed: _saving ? null : () => context.pop(),
            ),
          ],
        ),
        const Footnote(
          'Storage and quantity aren’t edited here. Use Move or Adjust '
          'quantity on the item so every change is recorded.',
        ),
      ],
    );
  }
}
