import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../models/recipe_match.dart';
import 'meal_widgets.dart';

/// Meal suggestion card (What can I cook?): photo, info and "View recipe".
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.match});
  final RecipeMatch match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = match.recipe;
    final allIn = match.isFullyAvailable;
    final available = match.availableRequired;
    final notEnough = match.missingRequired
        .where((m) => m.availability == IngredientAvailability.insufficient)
        .toList();
    final unitIssue = match.missingRequired
        .where((m) => m.availability == IngredientAvailability.unitMismatch)
        .toList();
    final missing = match.missingRequired
        .where((m) => m.availability == IngredientAvailability.missing)
        .toList();
    final optional = match.optional;

    Text line(String text, {Color? color, TextStyle style = AppTypography.body}) =>
        Text(text, style: style.copyWith(color: color ?? c.textPrimary));

    void open() => context.push(Routes.recipe(r.id));

    final children = <Widget>[
      Overline(r.mealType.label),
      Text(r.name,
          style: AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
      line(r.description, color: c.textMuted, style: AppTypography.subtitle),
      line(
        '${r.prepMinutes} min prep · ${r.cookMinutes} min cook · '
        '${r.difficulty.label} · Serves ${match.servings}',
        color: c.textMuted,
        style: AppTypography.caption,
      ),
      line(
        '${match.availableRequiredCount} of ${match.requiredCount} required '
        'ingredients available',
        color: allIn ? c.textPrimary : c.warning,
      ),
      if (available.isNotEmpty)
        line('Available / planned use: ${available.map((m) => '${m.ingredient.name} ${plannedAmount(m.ingredient)}').join(' · ')}'),
      if (notEnough.isNotEmpty)
        line('Not enough: ${notEnough.map(shortfallLabel).join('; ')}',
            color: c.warning),
      if (unitIssue.isNotEmpty)
        line('Check units: ${unitIssue.map(shortfallLabel).join('; ')}',
            color: c.warning),
      if (missing.isNotEmpty)
        line('Need to buy: ${missing.map(shortfallLabel).join('; ')}',
            color: c.warning),
      if (optional.isNotEmpty)
        line(
          'Optional: ${optional.map((m) => '${m.ingredient.amountLabel} · ${m.pantryItem != null ? 'in your pantry' : 'not in inventory'}').join('; ')}',
          color: c.textMuted,
          style: AppTypography.caption,
        ),
    ];

    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 10));
      spaced.add(children[i]);
    }

    return Semantics(
      container: true,
      label: '${r.name}, ${r.mealType.label}',
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImage(
              path: r.imagePath,
              height: 172,
              radius: AppRadii.card,
              semanticLabel: 'Illustrative photo of ${r.name}',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...spaced,
                  const SizedBox(height: 4),
                  Semantics(
                    button: true,
                    label: 'View recipe for ${r.name}',
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: open,
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('View recipe',
                                  style: AppTypography.subtitle
                                      .copyWith(color: c.textPrimary)),
                            ),
                            Icon(LucideIcons.arrowUpRight,
                                size: 19, color: c.textPrimary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
