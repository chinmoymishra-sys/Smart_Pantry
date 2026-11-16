import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
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

/// 09 · Manual draft, step 1: name, quantity, unit, category, state, storage.
/// Nothing reaches inventory until the details step is confirmed.
class ManualAddScreen extends ConsumerStatefulWidget {
  const ManualAddScreen({super.key});

  @override
  ConsumerState<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends ConsumerState<ManualAddScreen> {
  // Cached eagerly: dispose() uses it, and ref is unusable there.
  late final CaptureController _ctrl;

  final _name = TextEditingController();
  final _qty = TextEditingController();
  final _customName = TextEditingController();

  PantryUnit _unit = PantryUnit.pieces;
  FoodCategory _category = FoodCategory.vegetable;
  FoodState _foodState = FoodState.raw;
  StorageLocation _storage = StorageLocation.fridge;
  String? _photo;

  /// True once the user picked/removed a photo here; otherwise the draft's
  /// current photo (which the details step may have changed) is used.
  bool _photoTouched = false;

  /// Photo picked on this screen that isn't attached to the draft yet.
  String? _pendingPhoto;
  bool _prefilled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl = ref.read(captureControllerProvider.notifier);
    _prefill();
  }

  Future<void> _prefill() async {
    try {
      final draft = await ref.read(captureControllerProvider.future);
      final det = _manualDetection(draft);
      if (!mounted || det == null || _prefilled) return;
      setState(() {
        _prefilled = true;
        _name.text = det.name;
        _qty.text = det.quantity == null ? '' : formatNumber(det.quantity!);
        _unit = det.unit;
        _category = det.category;
        _foodState = det.foodState;
        _storage = det.storage;
        _customName.text = det.customLocationName ?? '';
      });
    } catch (_) {
      // Prefill is a convenience; an empty form still works.
    }
  }

  static DetectionDraft? _manualDetection(CaptureDraft? d) =>
      d != null &&
              d.status == CaptureDraftStatus.open &&
              d.method == CaptureMethod.manual &&
              d.detections.isNotEmpty
          ? d.detections.first
          : null;

  @override
  void dispose() {
    final p = _pendingPhoto;
    if (p != null) _ctrl.discardPhoto(p);
    _name.dispose();
    _qty.dispose();
    _customName.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final pick = await pickReviewPhoto(context, hasPhoto: _shownPhoto != null);
    if (pick == null || !mounted) return;
    try {
      final stored =
          pick.path == null ? null : await _ctrl.importPhoto(pick.path!);
      if (!mounted) return;
      final old = _pendingPhoto;
      setState(() {
        _photo = stored;
        _pendingPhoto = stored;
        _photoTouched = true;
      });
      if (old != null) await _ctrl.discardPhoto(old);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    final name = _name.text.trim();
    final qty = parseQuantity(_qty.text);
    if (name.isEmpty) {
      showAppSnack(context, 'Enter the item name.');
      return;
    }
    if (qty == null || qty <= 0) {
      showAppSnack(context, 'Enter a quantity above zero.');
      return;
    }
    setState(() => _busy = true);
    try {
      var draft = ref.read(captureControllerProvider).value;
      final open = draft != null && draft.status == CaptureDraftStatus.open;
      if (open && draft.method != CaptureMethod.manual) {
        final hasContent =
            draft.detections.isNotEmpty || draft.sourcePhotoPath != null;
        if (hasContent) {
          final ok = await showConfirmDialog(
            context,
            title: 'Discard your current review?',
            body:
                'You have an unsaved ${draft.method.label.toLowerCase()} draft with ${draft.detections.length} ${draft.detections.length == 1 ? 'item' : 'items'}. Starting a manual item discards it. Your pantry won’t change.',
            confirmLabel: 'Discard and continue',
            cancelLabel: 'Keep that draft',
            destructive: true,
          );
          if (!ok) return;
        }
        draft = await _ctrl.start(method: CaptureMethod.manual);
      } else if (!open) {
        draft = await _ctrl.start(method: CaptureMethod.manual);
      }
      final existing = _manualDetection(draft);
      final photo = _photoTouched ? _photo : existing?.photoPath;
      final base = existing ??
          _ctrl.newDetection(captureDraftId: draft.id);
      final det = base.copyWith(
        name: name,
        quantity: qty,
        unit: _unit,
        quantitySource: QuantitySource.userEntered,
        category: _category,
        foodState: _foodState,
        storage: _storage,
        customLocationName:
            _storage == StorageLocation.custom ? _customName.text.trim() : '',
        isIdentityConfirmed: true,
        isSelected: true,
        photoPath: photo,
        clearPhoto: photo == null,
      );
      await _ctrl.upsertDetection(det);
      _pendingPhoto = null;
      _photoTouched = false;
      if (mounted) context.push(Routes.manualDetails);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    final draft = ref.read(captureControllerProvider).value;
    setState(() => _busy = true);
    try {
      if (draft != null && draft.method == CaptureMethod.manual) {
        await _ctrl.cancel();
      }
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.scan);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? get _shownPhoto => _photoTouched
      ? _photo
      : _manualDetection(ref.read(captureControllerProvider).value)?.photoPath;

  @override
  Widget build(BuildContext context) {
    final livePhoto =
        _manualDetection(ref.watch(captureControllerProvider).value)?.photoPath;
    final shown = _photoTouched ? _photo : livePhoto;
    return AppPage(
      title: 'Add it your way',
      subtitle: 'A manual draft · not yet in inventory',
      children: [
        LabeledField(
          label: 'Item name',
          child: AppTextField(
            controller: _name,
            hint: 'e.g. Carrots',
            textInputAction: TextInputAction.next,
            semanticLabel: 'Item name',
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Quantity',
                    child: AppTextField(
                      controller: _qty,
                      hint: 'e.g. 2',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: quantityInputFormatters,
                      semanticLabel: 'Quantity',
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
                      onChanged: (u) => setState(() => _unit = u),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ChoiceChips<PantryUnit>(
              options: PantryUnit.selectable,
              selected: _unit,
              labelOf: (u) => u.dbValue,
              onSelected: (u) => setState(() => _unit = u),
            ),
          ],
        ),
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
          label: 'Storage',
          child: AppSelectField<StorageLocation>(
            title: 'Storage',
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
        if (shown != null)
          GestureDetector(
            onTap: () => showReviewPhotoViewer(context, shown),
            child: FoodImage(path: shown, height: 140, semanticLabel: 'Item photo'),
          ),
        AppButton.secondary(
          label: shown == null
              ? 'Add an item photo (optional)'
              : 'Replace / remove item photo',
          icon: LucideIcons.imagePlus,
          onPressed: _busy ? null : _pickPhoto,
        ),
        const InfoCallout(
          title: 'Only a name and quantity are required',
          body:
              'Dates are optional. Unknown quality and freshness stay “not assessed” until you record your own observation.',
        ),
        AppButton(
          label: 'Next: dates, condition & notes',
          loading: _busy,
          onPressed: _next,
        ),
        AppButton.secondary(
          label: 'Cancel draft',
          onPressed: _busy ? null : _cancel,
        ),
      ],
    );
  }
}
