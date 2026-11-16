import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../controllers/capture_controller.dart';
import '../../models/capture_models.dart';
import '../widgets/review_widgets.dart';

/// 09b · Manual draft, step 2: optional dates, condition, notes and photo,
/// then the explicit "Confirm & add" that writes to inventory.
class ManualDetailsScreen extends ConsumerStatefulWidget {
  const ManualDetailsScreen({super.key});

  @override
  ConsumerState<ManualDetailsScreen> createState() =>
      _ManualDetailsScreenState();
}

class _ManualDetailsScreenState extends ConsumerState<ManualDetailsScreen> {
  late final CaptureController _ctrl =
      ref.read(captureControllerProvider.notifier);
  final _notes = TextEditingController();

  DetectionDraft? _base;
  DateTime? _dateAdded;
  DateTime? _purchaseDate;
  DateTime? _expiry;
  DateType _dateType = DateType.useBy;
  DateTime? _opened;
  Condition _condition = Condition.notAssessed;
  Condition _freshness = Condition.notAssessed;
  String? _photo;
  bool _saving = false;
  bool _committed = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  static DetectionDraft? _manualDetection(CaptureDraft? d) =>
      d != null &&
              d.status == CaptureDraftStatus.open &&
              d.method == CaptureMethod.manual &&
              d.detections.isNotEmpty
          ? d.detections.first
          : null;

  void _init(DetectionDraft d) {
    _base = d;
    _dateAdded = d.dateAdded ?? AppDates.today();
    _purchaseDate = d.purchaseDate;
    _expiry = d.expiryDate;
    _dateType = d.dateType;
    _opened = d.openedDate;
    _condition = d.condition;
    _freshness = d.freshness;
    _photo = d.photoPath;
    _notes.text = d.notes ?? '';
  }

  DetectionDraft _current(DetectionDraft base) => base.copyWith(
        dateAdded: _dateAdded,
        purchaseDate: _purchaseDate,
        clearPurchaseDate: _purchaseDate == null,
        expiryDate: _expiry,
        clearExpiryDate: _expiry == null,
        dateType: _dateType,
        openedDate: _opened,
        clearOpenedDate: _opened == null,
        condition: _condition,
        freshness: _freshness,
        notes: _notes.text.trim(),
        photoPath: _photo,
        clearPhoto: _photo == null,
      );

  Future<void> _pickPhoto() async {
    final base = _base;
    if (base == null) return;
    final pick = await pickReviewPhoto(context, hasPhoto: _photo != null);
    if (pick == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final stored =
          pick.path == null ? null : await _ctrl.importPhoto(pick.path!);
      _photo = stored;
      // Attach right away so the draft owns the file (and the old one is
      // cleaned up by the controller).
      await _ctrl.upsertDetection(_current(base));
      _base = _manualDetection(ref.read(captureControllerProvider).value);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    if (_saving) return;
    final base = _base;
    if (base != null) {
      try {
        // Keep the details the user already entered for when they return.
        await _ctrl.upsertDetection(_current(base));
      } catch (_) {
        // Non-blocking: going back must always work.
      }
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.manualAdd);
    }
  }

  Future<void> _confirm() async {
    final base = _base;
    if (base == null || _saving) return;
    setState(() => _saving = true);
    try {
      await _ctrl.upsertDetection(_current(base));
      final result = await _ctrl.commit();
      _committed = true;
      ref.read(lastCommitProvider.notifier).set(result);
      if (mounted) context.go(Routes.saved);
    } catch (e) {
      if (mounted) {
        showAppSnack(context,
            '${friendlyError(e)} Nothing was added to your pantry.');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = 'A few optional details';
    final async = ref.watch(captureControllerProvider);
    final live = _manualDetection(async.value);
    if (_base == null && live != null) _init(live);

    if (_base == null || (live == null && !_committed && !_saving)) {
      if (async.isLoading) {
        return const AppPage(title: title, children: [LoadingView()]);
      }
      return AppPage(
        title: title,
        children: [
          StateCard(
            icon: LucideIcons.pencilLine,
            title: 'Start with a name and quantity',
            body: 'There’s no manual item in progress. Add one to continue.',
            actions: [
              AppButton(
                label: 'Add an item yourself',
                onPressed: () => context.pushReplacement(Routes.manualAdd),
              ),
            ],
          ),
        ],
      );
    }
    final base = _base!;
    final d = _current(base);
    final name = d.name.trim();
    final qty = d.hasQuantity ? formatQuantity(d.quantity!, d.unit) : '';
    final summary = [
      reviewJoin([name, qty, d.category.label, d.foodState.label, d.storageLabel]),
      _expiry == null
          ? 'No expiry or safety assessment has been inferred.'
          : '${d.dateType.label} ${AppDates.short(_expiry!)} is your date. No safety assessment has been inferred.',
    ].join('. ');

    return AppPage(
      title: title,
      subtitle: reviewJoin([name, qty, d.foodState.label, d.storageLabel]),
      onBack: _back,
      children: [
        LabeledField(
          label: 'Date added',
          child: AppDateField(
            label: 'Date added',
            value: _dateAdded,
            allowClear: false,
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
          label: 'Expiry / best-before',
          helper: 'Leave blank when you don’t have a recorded date.',
          child: AppDateField(
            label: 'Expiry or best-before date',
            value: _expiry,
            onChanged: (v) => setState(() => _expiry = v),
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
          label: 'Opened / prepared date',
          child: AppDateField(
            label: 'Opened or prepared date',
            value: _opened,
            onChanged: (v) => setState(() => _opened = v),
          ),
        ),
        LabeledField(
          label: 'Quality / condition',
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
          label: 'Notes (optional)',
          child: AppTextField(
            controller: _notes,
            hint: 'Add your own notes',
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            semanticLabel: 'Notes',
          ),
        ),
        if (_photo != null)
          GestureDetector(
            onTap: () => showReviewPhotoViewer(context, _photo!),
            child: FoodImage(path: _photo, height: 140, semanticLabel: 'Item photo'),
          ),
        AppButton.secondary(
          label: _photo == null ? 'Add an optional photo' : 'Replace / remove photo',
          icon: LucideIcons.imagePlus,
          onPressed: _saving ? null : _pickPhoto,
        ),
        InfoCallout(title: 'Review your manual item', body: summary),
        const Footnote('This manual draft hasn’t been saved to your pantry yet.'),
        AppButton(
          label: 'Confirm & add ${name.toLowerCase()}',
          icon: LucideIcons.check,
          loading: _saving,
          onPressed: _confirm,
        ),
        AppButton.secondary(
          label: 'Back to name & quantity',
          onPressed: _saving ? null : _back,
        ),
      ],
    );
  }
}
