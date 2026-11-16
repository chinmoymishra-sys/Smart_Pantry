import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_states.dart';

/// "04:32" countdown label.
String formatClock(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

String stepsCompleteLabel(int done, int total) =>
    '$done of $total step${total == 1 ? '' : 's'} complete';

/// Segmented step progress (N equal segments, h 5, gap 6, radius 100) with
/// the "1 of 4 steps complete" caption.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.total, required this.completed});

  final int total;
  final Set<int> completed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = completed.where((s) => s >= 1 && s <= total).length;
    return Semantics(
      label: stepsCompleteLabel(done, total),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= total; i++) ...[
                if (i > 1) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: completed.contains(i) ? c.textPrimary : c.border,
                      borderRadius: AppRadii.pillRadius,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(stepsCompleteLabel(done, total),
              style: AppTypography.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

/// Shown when no open cooking session exists.
class NoCookingSessionCard extends StatelessWidget {
  const NoCookingSessionCard({super.key, this.title, this.body});

  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) => StateCard(
        icon: LucideIcons.utensils,
        title: title ?? 'No cooking in progress',
        body: body ??
            'Pick a recipe from Meals to start cooking. Your pantry is unchanged.',
        actions: [
          AppButton(
            label: 'Browse meals',
            icon: LucideIcons.utensils,
            onPressed: () => context.go(Routes.meals),
          ),
        ],
      );
}

/// Shown when the session's recipe can't be found on this device.
class MissingRecipeCard extends StatelessWidget {
  const MissingRecipeCard({super.key});

  @override
  Widget build(BuildContext context) => StateCard(
        icon: LucideIcons.circleAlert,
        title: 'Recipe not found',
        body:
            'This cooking session’s recipe is no longer on this device. Your pantry is unchanged.',
        actions: [
          AppButton(
            label: 'Browse meals',
            onPressed: () => context.go(Routes.meals),
          ),
        ],
      );
}
