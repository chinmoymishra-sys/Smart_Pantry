import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../controllers/capture_controller.dart';
import '../widgets/acq_capture_actions.dart';

/// 04 · Capture / photo approval.
class SelectedPhotoScreen extends ConsumerStatefulWidget {
  const SelectedPhotoScreen({super.key});

  @override
  ConsumerState<SelectedPhotoScreen> createState() =>
      _SelectedPhotoScreenState();
}

class _SelectedPhotoScreenState extends ConsumerState<SelectedPhotoScreen> {
  bool _working = false;

  Future<void> _replaceFromGallery() async {
    if (_working) return;
    final path = await acqPickGalleryPhoto(context);
    if (path == null || !mounted) return;
    setState(() => _working = true);
    try {
      await ref
          .read(captureControllerProvider.notifier)
          .replaceSourcePhoto(path);
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _replaceSheet() async {
    final c = context.colors;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  'Replace this photo',
                  style: AppTypography.sectionTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              ListTile(
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.buttonRadius,
                ),
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
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadii.buttonRadius,
                ),
                leading: Icon(
                  LucideIcons.images,
                  size: 22,
                  color: c.textPrimary,
                ),
                title: Text(
                  'Choose from gallery',
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
      context.push(acqCameraReplaceRoute);
    } else {
      await _replaceFromGallery();
    }
  }

  Future<void> _remove() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove this photo?',
      body: 'The photo is discarded and nothing is added to your pantry.',
      confirmLabel: 'Remove photo',
      cancelLabel: 'Keep photo',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _working = true);
    try {
      await ref.read(captureControllerProvider.notifier).cancel();
      if (mounted) context.go(Routes.scan);
    } catch (e) {
      if (mounted) {
        setState(() => _working = false);
        showAppSnack(context, friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(captureControllerProvider);
    return async.when(
      loading: () => const AppPage(
        title: 'Ready for a closer look?',
        children: [LoadingView()],
      ),
      error: (e, _) => AppPage(
        title: 'Ready for a closer look?',
        children: [
          ErrorStateView(
            error: e,
            onRetry: () => ref.invalidate(captureControllerProvider),
          ),
        ],
      ),
      data: (draft) {
        final photo = draft?.sourcePhotoPath;
        if (draft == null || photo == null) {
          return AppPage(
            title: 'Ready for a closer look?',
            subtitle: 'No photo selected',
            children: [
              StateCard(
                icon: LucideIcons.imageOff,
                title: 'No photo to review',
                body:
                    'There isn’t a selected photo right now. Take or choose '
                    'one from Scan & add. Nothing has been saved.',
                actions: [
                  AppButton(
                    label: 'Back to Scan & add',
                    onPressed: () => context.go(Routes.scan),
                  ),
                ],
              ),
            ],
          );
        }
        return AppPage(
          title: 'Ready for a closer look?',
          subtitle: 'Selected photo · 1 image',
          children: [
            FoodImage(
              key: ValueKey(photo),
              path: photo,
              height: 340,
              semanticLabel: 'Your selected food photo',
            ),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'Replace / retake',
                    icon: LucideIcons.refreshCw,
                    onPressed: _working ? null : _replaceSheet,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton.danger(
                    label: 'Remove',
                    icon: LucideIcons.trash2,
                    onPressed: _working ? null : _remove,
                  ),
                ),
              ],
            ),
            const InfoCallout(
              title: 'Send this photo for recognition',
              body:
                  'Identify food uploads this image for analysis. Only the '
                  'items you later confirm will be added to inventory.',
            ),
            Text(
              'A photo may suggest names and counts. It cannot tell exact '
              'weight, hidden ingredients, expiry or whether food is safe.',
              style: AppTypography.body.copyWith(color: c.textMuted),
            ),
            Column(
              children: [
                AppButton(
                  label: 'Identify food',
                  icon: LucideIcons.scanSearch,
                  onPressed: _working
                      ? null
                      : () => context.push(Routes.recognition),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton.secondary(
                  label: 'Choose from files',
                  onPressed: _working ? null : _replaceFromGallery,
                  loading: _working,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
