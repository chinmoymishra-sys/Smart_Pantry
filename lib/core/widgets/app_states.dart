import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../errors/app_exceptions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_surfaces.dart';

/// Compact state card from the design's state library: overline, 26px icon,
/// 20px title, 14px body, then actions.
class StateCard extends StatelessWidget {
  const StateCard({
    super.key,
    required this.title,
    required this.body,
    this.overline,
    this.icon,
    this.actions = const [],
    this.extra,
  });

  final String? overline;
  final IconData? icon;
  final String title;
  final String body;
  final List<Widget> actions;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overline != null) ...[
            Overline(overline!, muted: true),
            const SizedBox(height: 14),
          ],
          if (icon != null) ...[
            Icon(icon, size: 26, color: c.textPrimary),
            const SizedBox(height: 14),
          ],
          Semantics(
            header: true,
            child: Text(title,
                style: AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 10),
          Text(body, style: AppTypography.subtitle.copyWith(color: c.textMuted)),
          if (extra != null) ...[const SizedBox(height: 14), extra!],
          for (var i = 0; i < actions.length; i++) ...[
            SizedBox(height: i == 0 ? 16 : 12),
            actions[i],
          ],
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: c.textPrimary),
            ),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(label!, style: AppTypography.body.copyWith(color: c.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => StateCard(
        icon: LucideIcons.circleAlert,
        title: 'Something went wrong on this device',
        body: '${friendlyError(error)} Your saved pantry data hasn’t changed.',
        actions: [
          if (onRetry != null)
            AppButton(label: 'Try again', icon: LucideIcons.refreshCw, onPressed: onRetry),
        ],
      );
}

String friendlyError(Object e) {
  if (e is ValidationException) return e.message;
  if (e is NotFoundException) return e.message;
  if (e is StateError) return e.message;
  return 'The local database couldn’t complete that action.';
}

void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Two-button confirmation dialog. Returns true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final c = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 10),
            Text(body, style: AppTypography.subtitle.copyWith(color: c.textMuted)),
            const SizedBox(height: 20),
            AppButton(
              label: confirmLabel,
              icon: destructive ? LucideIcons.trash2 : null,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton.secondary(
              label: cancelLabel,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
