import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/widgets/app_states.dart';
import '../../controllers/capture_controller.dart';
import '../../models/capture_models.dart';

/// Shared capture-start helpers for the acquisition screens.

/// Camera route that replaces the photo of the open draft (then pops back).
const acqCameraReplaceRoute = '${Routes.camera}?mode=replace';

/// Camera route used after the user already agreed to start a fresh scan.
const acqCameraFreshRoute = '${Routes.camera}?confirmed=1';

/// True when the open draft holds something the user would lose.
bool acqDraftHasContent(CaptureDraft? d) =>
    d != null &&
    d.status == CaptureDraftStatus.open &&
    (d.sourcePhotoPath != null || d.detections.isNotEmpty);

/// Asks before a new capture replaces an open draft that has content.
/// Returns true when it is fine to start (no content, or user agreed).
/// The old draft is cancelled only when `start()` actually runs.
Future<bool> acqConfirmFreshStart(BuildContext context, WidgetRef ref) async {
  final d = ref.read(captureControllerProvider).value;
  if (!acqDraftHasContent(d)) return true;
  final n = d!.detections.length;
  final what = n == 0
      ? 'your selected photo'
      : 'your open review ($n ${n == 1 ? 'item' : 'items'})';
  return showConfirmDialog(
    context,
    title: 'Start a new scan?',
    body: 'Starting again discards $what. Nothing in your pantry changes.',
    confirmLabel: 'Start new scan',
    cancelLabel: 'Keep current review',
  );
}

/// Opens the gallery picker. Returns the picked path, or null when the user
/// cancelled or access was denied (in which case the permission screen is
/// shown when [routeOnDenied] is true, otherwise a message).
Future<String?> acqPickGalleryPhoto(
  BuildContext context, {
  bool routeOnDenied = true,
}) async {
  try {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    return x?.path;
  } on PlatformException catch (e) {
    if (!context.mounted) return null;
    if (e.code == 'photo_access_denied' ||
        e.code == 'photo_access_restricted') {
      if (routeOnDenied) {
        context.push(Routes.permission('gallery'));
      } else {
        showAppSnack(
          context,
          'Photo access is still off. Allow it in Settings.',
        );
      }
    } else {
      showAppSnack(context, 'Couldn’t open your photos. Try again.');
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      showAppSnack(context, 'Couldn’t open your photos on this device.');
    }
    return null;
  }
}

/// Upload flow: confirm replacing an open draft → pick → start(upload) →
/// Selected photo. [replace] swaps the current route instead of pushing.
Future<void> acqStartUpload(
  BuildContext context,
  WidgetRef ref, {
  bool replace = false,
  bool routeOnDenied = true,
  bool skipConfirm = false,
}) async {
  if (!skipConfirm && !await acqConfirmFreshStart(context, ref)) return;
  if (!context.mounted) return;
  final path = await acqPickGalleryPhoto(context, routeOnDenied: routeOnDenied);
  if (path == null || !context.mounted) return;
  try {
    await ref
        .read(captureControllerProvider.notifier)
        .start(method: CaptureMethod.upload, sourcePhotoPath: path);
    if (!context.mounted) return;
    if (replace) {
      context.pushReplacement(Routes.selectedPhoto);
    } else {
      context.push(Routes.selectedPhoto);
    }
  } catch (e) {
    if (context.mounted) showAppSnack(context, friendlyError(e));
  }
}
