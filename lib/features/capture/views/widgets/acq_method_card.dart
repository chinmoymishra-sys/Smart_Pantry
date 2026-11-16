import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_surfaces.dart';

/// Capture method card (Scan & add): icon 26 · title 15 / subtitle 13 muted ·
/// chevron-right 18.
class AcqMethodCard extends StatelessWidget {
  const AcqMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 26, color: c.textPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.title.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.body.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textPrimary),
          ],
        ),
      ),
    );
  }
}
