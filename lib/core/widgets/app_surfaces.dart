import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppCardTone { surface, muted, danger, warning }

/// Card: white surface, 1px border, radius 18, padding 16 (design default).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.tone = AppCardTone.surface,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.selected = false,
    this.radius = AppRadii.card,
  });

  final Widget child;
  final AppCardTone tone;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color bg = switch (tone) {
      AppCardTone.surface => selected ? c.surfaceMuted : c.surface,
      AppCardTone.muted => c.surfaceMuted,
      AppCardTone.danger => c.dangerSurface,
      AppCardTone.warning => c.warningSurface,
    };
    final Color border = selected
        ? c.textPrimary
        : (tone == AppCardTone.surface ? c.border : Colors.transparent);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: border),
    );
    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

enum CalloutTone { neutral, warning, danger }

/// Guidance banner: icon 19 + title 13 + body 13 muted, radius 10, pad 14.
class InfoCallout extends StatelessWidget {
  const InfoCallout({
    super.key,
    required this.title,
    this.body,
    this.tone = CalloutTone.neutral,
    this.icon,
  });

  final String title;
  final String? body;
  final CalloutTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color titleColor, IconData ic) = switch (tone) {
      CalloutTone.neutral => (c.surfaceMuted, c.textPrimary, LucideIcons.info),
      CalloutTone.warning =>
        (c.warningSurface, c.warning, LucideIcons.circleAlert),
      CalloutTone.danger => (c.dangerSurface, c.danger, LucideIcons.circleAlert),
    };
    return Container(
      width: double.infinity,
      padding: AppSpacing.calloutPadding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.buttonRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? ic, size: 19, color: titleColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body.copyWith(color: titleColor)),
                if (body != null) ...[
                  const SizedBox(height: 4),
                  Text(body!,
                      style: AppTypography.body.copyWith(color: c.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading (20px) with an optional trailing Semi Bold 13 action.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title,
                style: AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
          ),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                widthFactor: 1,
                child: Text(action!,
                    style: AppTypography.label.copyWith(color: c.textPrimary)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Label/value rows with a fixed 140px label column (design summary card).
class DetailRows extends StatelessWidget {
  const DetailRows(this.rows, {super.key, this.labelWidth = 140});

  final List<(String, String)> rows;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(rows[i].$1,
                    style: AppTypography.body.copyWith(color: c.textMuted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(rows[i].$2,
                    style: AppTypography.body.copyWith(color: c.textPrimary)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Small muted footnote (12px).
class Footnote extends StatelessWidget {
  const Footnote(this.text, {super.key, this.color, this.textAlign});
  final String text;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: textAlign,
        style: AppTypography.caption.copyWith(color: color ?? context.colors.textMuted),
      );
}

/// Uppercase overline (11px), e.g. "BREAKFAST", "OPTIONAL".
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.muted = false});
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTypography.overline.copyWith(
          color: muted ? context.colors.textMuted : context.colors.textPrimary,
        ),
      );
}

/// Storage count tile (Overview): label 13 muted above a 25px count.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.onTap});
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.body.copyWith(color: c.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: AppTypography.stat.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}
