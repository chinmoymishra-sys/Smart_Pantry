import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Standard screen layout from the design: optional "Back" row (44 high),
/// 28px title, 14px muted subtitle, then content sections separated by 20px.
///
/// Tab screens (bottom navigation visible) set [showBack] to false; the
/// navigation shell supplies the bottom bar.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.gap = AppSpacing.section,
    this.controller,
    this.titleWidget,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  /// Override back behaviour (e.g. confirm before discarding a draft).
  final VoidCallback? onBack;
  final double gap;
  final ScrollController? controller;
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) content.add(SizedBox(height: gap));
      content.add(children[i]);
    }
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: AppSpacing.headerPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBack) ...[
                      BackRow(onBack: onBack),
                      const SizedBox(height: 4),
                    ],
                    Semantics(
                      header: true,
                      child: titleWidget ??
                          Text(title,
                              style: AppTypography.pageTitle
                                  .copyWith(color: c.textPrimary)),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 12),
                      Text(subtitle!,
                          style: AppTypography.subtitle
                              .copyWith(color: c.textMuted)),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: AppSpacing.contentPadding.copyWith(
                bottom: AppSpacing.contentPadding.bottom +
                    MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverList(delegate: SliverChildListDelegate(content)),
            ),
          ],
        ),
      ),
    );
  }
}

/// "← Back" control (44px high, arrow-left 20 + 13px label).
class BackRow extends StatelessWidget {
  const BackRow({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Back',
      excludeSemantics: true,
      child: InkWell(
        onTap: onBack ??
            () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.arrowLeft, size: 20, color: c.textPrimary),
              const SizedBox(width: 6),
              Text('Back',
                  style: AppTypography.body.copyWith(color: c.textPrimary)),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
