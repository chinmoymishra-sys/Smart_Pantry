import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Pill choice chip: min height 44, padding 14×11, label 13. Selected state
/// is a filled pill with a 14px check icon.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCheck = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.onPrimary : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.primary : c.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? c.primaryBorder : c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected && showCheck) ...[
                    Icon(LucideIcons.check, size: 14, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Text(label, style: AppTypography.body.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps chips with the design's 8px spacing.
class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

/// Single-select chip group bound to a list of options.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => ChipWrap(
        children: [
          for (final o in options)
            AppChip(
              label: labelOf(o),
              selected: o == selected,
              onTap: () => onSelected(o),
            ),
        ],
      );
}

/// Read-only status pill ("2 use soon", "1 low stock").
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      shape: StadiumBorder(side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(label,
                  style: AppTypography.body.copyWith(color: c.textPrimary)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Radio-style option card (Move screen): circle / circle-check icon.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.surfaceMuted : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.buttonRadius,
          side: BorderSide(color: selected ? c.textPrimary : c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    selected ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 22,
                    color: selected ? c.textPrimary : c.textMuted,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(label,
                        style: AppTypography.title.copyWith(color: c.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
