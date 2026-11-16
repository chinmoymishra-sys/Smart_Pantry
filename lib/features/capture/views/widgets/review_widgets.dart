import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_states.dart';

/// Filled square checkbox from the review design (primary fill + white check
/// when selected, outlined when not). Minimum 44px tap target.
class ReviewCheckbox extends StatelessWidget {
  const ReviewCheckbox({
    super.key,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    this.size = 26,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      checked: selected,
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: selected ? c.primary : c.surface,
                borderRadius: BorderRadius.circular(size * 0.23),
                border: Border.all(
                  color: selected ? c.primaryBorder : c.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Icon(
                      LucideIcons.check,
                      size: size * 0.62,
                      color: c.onPrimary,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a full-screen, zoomable view of a draft photo.
Future<void> showReviewPhotoViewer(BuildContext context, String path) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (ctx) {
      final c = ctx.colors;
      final image = path.startsWith('assets/')
          ? Image.asset(path, fit: BoxFit.contain)
          : Image.file(
              File(path),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(LucideIcons.imageOff, size: 32, color: c.textMuted),
            );
      return Dialog.fullscreen(
        backgroundColor: c.cameraSurface,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Semantics(
                      image: true,
                      label: 'Original photo',
                      child: image,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: RoundIconButton(
                  icon: LucideIcons.x,
                  semanticLabel: 'Close photo',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

enum _PhotoAction { camera, gallery, remove }

/// Result of [pickReviewPhoto]: [path] is the picked (temporary) file, or
/// null when the user chose to remove the current photo.
class ReviewPhotoPick {
  const ReviewPhotoPick(this.path);
  final String? path;
}

/// Lets the user take/choose a photo or remove the current one. Returns null
/// when cancelled or when the picker is unavailable (a snack explains why).
Future<ReviewPhotoPick?> pickReviewPhoto(
  BuildContext context, {
  required bool hasPhoto,
}) async {
  final action = await showOptionSheet<_PhotoAction>(
    context,
    title: hasPhoto ? 'Item photo' : 'Add a photo',
    options: [
      _PhotoAction.camera,
      _PhotoAction.gallery,
      if (hasPhoto) _PhotoAction.remove,
    ],
    labelOf: (a) => switch (a) {
      _PhotoAction.camera => 'Take a photo',
      _PhotoAction.gallery => 'Choose from your photos',
      _PhotoAction.remove => 'Remove photo',
    },
  );
  if (action == null) return null;
  if (action == _PhotoAction.remove) return const ReviewPhotoPick(null);
  try {
    final file = await ImagePicker().pickImage(
      source: action == _PhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 85,
    );
    if (file == null) return null;
    return ReviewPhotoPick(file.path);
  } on PlatformException {
    if (context.mounted) {
      showAppSnack(
        context,
        'Photo access isn’t available. Check camera and photo permissions in Settings.',
      );
    }
    return null;
  }
}

/// "Label: value" separator used across review rows.
String reviewJoin(Iterable<String> parts) =>
    parts.where((p) => p.trim().isNotEmpty).join(' · ');
