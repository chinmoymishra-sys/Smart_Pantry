import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../controllers/capture_controller.dart';
import '../../services/recognition_service.dart';
import '../widgets/acq_capture_actions.dart';

/// Sends the selected photo to the recognition boundary and shows the
/// loading / no-food / unavailable states. In this build no recognition
/// service is integrated, so the honest "unavailable" state is shown.
class RecognitionScreen extends ConsumerStatefulWidget {
  const RecognitionScreen({super.key});

  @override
  ConsumerState<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends ConsumerState<RecognitionScreen> {
  RecognitionResult? _result;
  bool _cancelled = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    final service = ref.read(recognitionServiceProvider);
    if (!service.isAvailable) {
      // Nothing to wait for — never pretend to upload or analyse.
      _result = RecognitionResult.unavailable;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run();
      });
    }
  }

  Future<void> _run() async {
    final photo = ref.read(captureControllerProvider).value?.sourcePhotoPath;
    if (photo == null) {
      setState(() => _result = RecognitionResult.unavailable);
      return;
    }
    setState(() {
      _result = null;
      _cancelled = false;
    });
    RecognitionResult r;
    try {
      r = await ref.read(recognitionServiceProvider).identify(photo);
    } catch (_) {
      r = RecognitionResult.unavailable;
    }
    if (!mounted || _cancelled) return;
    if (r.outcome == RecognitionOutcome.detected && r.foods.isNotEmpty) {
      await _addSuggestions(r);
      return;
    }
    setState(
      () => _result = r.outcome == RecognitionOutcome.detected
          ? RecognitionResult.noFood
          : r,
    );
  }

  /// Adds service suggestions as unconfirmed detections, then opens review.
  Future<void> _addSuggestions(RecognitionResult r) async {
    final ctrl = ref.read(captureControllerProvider.notifier);
    if (ctrl.draft == null) return;
    // Suggestions arrive unconfirmed; review requires the user to confirm
    // identity and enter a quantity before anything can be saved.
    final added = await ctrl.addSuggestedDetections([
      for (final f in r.foods)
        (name: f.name, category: f.category, quantity: f.quantity, unit: f.unit),
    ]);
    if (!mounted) return;
    final missingCount = r.foods.where((f) => f.quantity == null).length;
    if (added > 0 && missingCount > 0) {
      showAppSnack(
        context,
        '$missingCount suggestion${missingCount == 1 ? '' : 's'} need${missingCount == 1 ? 's' : ''} a quantity from you in review.',
      );
    }
    context.pushReplacement(Routes.review);
  }

  void _cancel() {
    _cancelled = true;
    context.pop();
  }

  Future<void> _addFromPhoto() async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      // Keep the open draft (with its photo); make sure one exists.
      await ref
          .read(captureControllerProvider.notifier)
          .ensureDraft(method: CaptureMethod.upload);
      if (mounted) context.pushReplacement(Routes.review);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _retakeSheet() async {
    final c = context.colors;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  LucideIcons.camera,
                  size: 22,
                  color: c.textPrimary,
                ),
                title: Text(
                  'Take a new photo',
                  style: AppTypography.title.copyWith(color: c.textPrimary),
                ),
                onTap: () => Navigator.of(ctx).pop('camera'),
              ),
              ListTile(
                leading: Icon(
                  LucideIcons.images,
                  size: 22,
                  color: c.textPrimary,
                ),
                title: Text(
                  'Choose another photo',
                  style: AppTypography.title.copyWith(color: c.textPrimary),
                ),
                onTap: () => Navigator.of(ctx).pop('gallery'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'camera') {
      context.pushReplacement(acqCameraReplaceRoute);
      return;
    }
    final path = await acqPickGalleryPhoto(context);
    if (path == null || !mounted) return;
    try {
      await ref
          .read(captureControllerProvider.notifier)
          .replaceSourcePhoto(path);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(captureControllerProvider).value;
    final r = _result;
    final Widget body;
    if (draft?.sourcePhotoPath == null) {
      body = StateCard(
        icon: LucideIcons.imageOff,
        title: 'No photo to identify',
        body: 'Take or choose a photo first. Nothing has been saved.',
        actions: [
          AppButton(
            label: 'Back to Scan & add',
            onPressed: () => context.go(Routes.scan),
          ),
        ],
      );
    } else if (r == null) {
      body = _LoadingCard(onCancel: _cancel);
    } else if (r.outcome == RecognitionOutcome.noFood) {
      body = StateCard(
        overline: 'RECOGNITION · NO FOOD DETECTED',
        icon: LucideIcons.scanSearch,
        title: 'We couldn’t make out the food',
        body:
            'The image may be too dark, blurry or covered. No detections '
            'were saved. Try a closer, well-lit photo with the food visible.',
        actions: [
          AppButton(
            label: 'Retake / choose another photo',
            onPressed: _retakeSheet,
          ),
          AppButton.secondary(
            label: 'Add items manually',
            onPressed: () => context.push(Routes.manualAdd),
          ),
        ],
      );
    } else {
      body = StateCard(
        overline: 'RECOGNITION · UNAVAILABLE',
        icon: LucideIcons.cloudOff,
        title: 'Recognition isn’t available yet',
        body:
            'Photo recognition needs a connected service that this version '
            'doesn’t include. We haven’t created or saved any items, and your '
            'photo stays on this device. Add the foods you can see — your '
            'photo stays with the review.',
        actions: [
          AppButton(
            label: 'Add items from this photo',
            icon: LucideIcons.pencilLine,
            loading: _adding,
            onPressed: _addFromPhoto,
          ),
          AppButton.secondary(
            label: 'Scan barcode / QR',
            onPressed: () => context.push(Routes.barcode),
          ),
          AppButton.secondary(
            label: 'Add manually',
            onPressed: () => context.push(Routes.manualAdd),
          ),
        ],
      );
    }
    return AppPage(
      title: 'Identify food',
      subtitle: 'Selected photo · Nothing is saved yet',
      children: [body],
    );
  }
}

/// RECOGNITION · LOADING card.
class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Overline('RECOGNITION · LOADING', muted: true),
            const SizedBox(height: 14),
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Taking a closer look…',
              style: AppTypography.sectionTitle.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            Text(
              'Looking for separate foods and visible labels. You’ll review '
              'everything before saving.',
              style: AppTypography.subtitle.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                color: c.primary,
                backgroundColor: c.surfaceMuted,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Photo sent · identifying items',
              style: AppTypography.body.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 16),
            AppButton.secondary(
              label: 'Cancel recognition',
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}
