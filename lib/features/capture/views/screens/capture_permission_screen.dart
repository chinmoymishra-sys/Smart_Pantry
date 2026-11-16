import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../widgets/acq_capture_actions.dart';

/// Camera / gallery permission denied state (State library 31).
/// [kind] is `camera` or `gallery`.
class CapturePermissionScreen extends ConsumerWidget {
  const CapturePermissionScreen({super.key, required this.kind});

  final String kind;

  Future<void> _openSettings(BuildContext context) async {
    var opened = false;
    try {
      opened = await openAppSettings();
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showAppSnack(
        context,
        'Couldn’t open Settings. Open your device Settings and allow access for Smart Pantry.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camera = kind != 'gallery';
    return AppPage(
      title: camera ? 'Camera access' : 'Photo access',
      subtitle: 'Nothing is saved yet',
      children: [
        StateCard(
          overline: camera
              ? 'CAMERA · PERMISSION DENIED'
              : 'GALLERY · PERMISSION DENIED',
          icon: camera ? LucideIcons.cameraOff : LucideIcons.imageOff,
          title: camera ? 'Camera access is off' : 'Your photos stay private',
          body: camera
              ? 'Smart Pantry needs camera access to photograph food or scan a '
                    'barcode. Enable it in Settings, or add food another way.'
              : 'Photo access is off. Allow selected-photo access in Settings '
                    'to choose an image, or select a file instead. Choosing an '
                    'image doesn’t upload it.',
          actions: [
            AppButton(
              label: camera ? 'Open device Settings' : 'Open photo Settings',
              onPressed: () => _openSettings(context),
            ),
            AppButton.secondary(
              label: camera ? 'Upload a photo instead' : 'Choose from files',
              onPressed: () => acqStartUpload(
                context,
                ref,
                replace: true,
                routeOnDenied: false,
              ),
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
}
