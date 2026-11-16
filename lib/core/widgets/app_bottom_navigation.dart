import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Shell hosting the four primary destinations from the design:
/// Overview, Scan/Add, Inventory, Meals.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: shell.currentIndex,
        onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    (LucideIcons.house, 'Overview'),
    (LucideIcons.scanLine, 'Scan/Add'),
    (LucideIcons.refrigerator, 'Inventory'),
    (LucideIcons.utensils, 'Meals'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _Destination(
                    icon: _items[i].$1,
                    label: _items[i].$2,
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = selected ? c.textPrimary : c.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 5),
              Text(
                label,
                style: AppTypography.navLabel.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
