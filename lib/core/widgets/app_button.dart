import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, danger }

/// Full-width flow button from the design: min height 52, radius 10,
/// Inter Regular 15, optional 20px leading icon with a 10px gap.
/// A null [onPressed] renders the muted disabled style
/// ("Confirm 1 item to save 3").
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
  });

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.danger;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !loading;
    final Color bg, fg, border;
    if (!enabled && !loading) {
      bg = c.surfaceMuted;
      fg = c.textMuted;
      border = Colors.transparent;
    } else {
      switch (variant) {
        case AppButtonVariant.primary:
          bg = c.primary;
          fg = c.onPrimary;
          border = c.primaryBorder;
        case AppButtonVariant.secondary:
          bg = c.surface;
          fg = c.textPrimary;
          border = c.border;
        case AppButtonVariant.danger:
          bg = c.surface;
          fg = c.danger;
          border = c.border;
      }
    }
    final disabledLook = !enabled && !loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: fg),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(icon, size: 20, color: fg),
          ),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.button.copyWith(
              color: fg,
              fontWeight: disabledLook ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.buttonRadius,
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Center(widthFactor: expand ? null : 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small inline text action ("Edit", "Skip", "View inventory").
class TextAction extends StatelessWidget {
  const TextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.danger = false,
    this.strong = true,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final bool strong;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontSize: fontSize,
                color: danger
                    ? c.danger
                    : (onPressed == null ? c.textMuted : c.textPrimary),
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button used for steppers / timer (48px, surface fill).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 48,
    this.filled = true,
    this.square = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final bool filled;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: filled ? (square ? c.surfaceMuted : c.surface) : Colors.transparent,
        shape: square
            ? const RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius)
            : const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              size: 22,
              color: onPressed == null ? c.textMuted : c.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
