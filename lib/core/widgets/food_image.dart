import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Rounded, cover-fit food photo from a bundled asset (`assets/…`) or an
/// app-managed local file. Falls back to a neutral placeholder so layout
/// stays stable when an image is missing.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.radius = AppRadii.card,
    this.aspectRatio,
    this.semanticLabel,
  });

  final String? path;
  final double? height;
  final double? width;
  final double radius;
  final double? aspectRatio;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget placeholder() => Container(
          color: c.surfaceMuted,
          alignment: Alignment.center,
          child: Icon(LucideIcons.image, size: 24, color: c.textMuted),
        );
    final p = path;
    Widget img;
    if (p == null || p.isEmpty) {
      img = placeholder();
    } else if (p.startsWith('assets/')) {
      img = Image.asset(p,
          fit: BoxFit.cover,
          semanticLabel: semanticLabel,
          errorBuilder: (_, _, _) => placeholder());
    } else {
      img = Image.file(File(p),
          fit: BoxFit.cover,
          semanticLabel: semanticLabel,
          errorBuilder: (_, _, _) => placeholder());
    }
    Widget box = SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: img,
      ),
    );
    if (aspectRatio != null && height == null) {
      box = AspectRatio(aspectRatio: aspectRatio!, child: box);
    }
    return box;
  }
}
