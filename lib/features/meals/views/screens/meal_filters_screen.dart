import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../controllers/meals_controller.dart';
import '../../models/meal_preferences.dart';
import '../widgets/meal_widgets.dart';

/// Meal preferences editor. Works on a local copy; nothing is saved until
/// "Show N ideas" is pressed.
class MealFiltersScreen extends ConsumerStatefulWidget {
  const MealFiltersScreen({super.key});

  @override
  ConsumerState<MealFiltersScreen> createState() => _MealFiltersScreenState();
}

class _MealFiltersScreenState extends ConsumerState<MealFiltersScreen> {
  MealPreferences? _local;
  bool _saving = false;

  void _set(MealPreferences p) => setState(() => _local = p);

  Future<void> _save(MealPreferences p) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(mealPreferencesProvider.notifier).save(p);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editExclusions(MealPreferences p) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ExclusionsSheet(initial: p.excludedIngredients),
    );
    if (result != null && mounted) _set(p.copyWith(excludedIngredients: result));
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(mealPreferencesProvider);
    final all = ref.watch(allRecipeMatchesProvider).value;
    if (_local == null && saved.hasValue) _local = saved.value;
    final p = _local;

    if (p == null) {
      return AppPage(
        title: 'Find your kind of meal',
        subtitle: 'Suggestions adapt to your pantry and choices.',
        children: [
          saved.hasError
              ? ErrorStateView(
                  error: saved.error!,
                  onRetry: () => ref.invalidate(mealPreferencesProvider))
              : const LoadingView(),
        ],
      );
    }

    final count = all == null ? null : filterAndSortMatches(all, p).length;
    final word = mealWord(p.mealType);
    final showLabel = count == null
        ? 'Show $word ideas'
        : 'Show $count $word idea${count == 1 ? '' : 's'}';

    Widget section(String title, Widget chips) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeading(title),
            const SizedBox(height: 14),
            chips,
          ],
        );

    return AppPage(
      title: 'Find your kind of meal',
      subtitle: 'Suggestions adapt to your pantry and choices.',
      children: [
        section(
          'Meal type',
          ChoiceChips<MealType?>(
            options: const [null, ...MealType.values],
            selected: p.mealType,
            labelOf: (t) => switch (t) {
              null => 'Any meal',
              MealType.snacks => 'Evening snacks',
              _ => t.label,
            },
            onSelected: (t) =>
                _set(p.copyWith(mealType: t, clearMealType: t == null)),
          ),
        ),
        section(
          'Total time',
          ChoiceChips<int?>(
            options: const [null, ...MealPreferences.timeOptions],
            selected: p.maxMinutes,
            labelOf: timeLabel,
            onSelected: (m) =>
                _set(p.copyWith(maxMinutes: m, clearMaxMinutes: m == null)),
          ),
        ),
        section(
          'Difficulty',
          ChoiceChips<Difficulty?>(
            options: const [null, ...Difficulty.values],
            selected: p.difficulty,
            labelOf: (d) => d?.label ?? 'Any',
            onSelected: (d) =>
                _set(p.copyWith(difficulty: d, clearDifficulty: d == null)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Pantry match'),
            const SizedBox(height: 14),
            ChipWrap(
              children: [
                for (final m in PantryMatchMode.values)
                  AppChip(
                    label: m.label,
                    selected: p.matchMode == m,
                    onTap: () => _set(p.copyWith(matchMode: m)),
                  ),
                AppChip(
                  label: 'Use soon first',
                  selected: p.useSoonFirst,
                  onTap: () =>
                      _set(p.copyWith(useSoonFirst: !p.useSoonFirst)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Footnote(
              'Available only means all required ingredients are stocked. '
              'Optional extras don’t affect the match.',
            ),
          ],
        ),
        section(
          'Dietary preference',
          ChoiceChips<String?>(
            options: const [null, ...MealPreferences.dietaryOptions],
            selected: p.dietaryPreference,
            labelOf: (d) => d ?? 'No preference',
            onSelected: (d) => _set(
                p.copyWith(dietaryPreference: d, clearDietary: d == null)),
          ),
        ),
        LabeledField(
          label: 'Allergies / exclude ingredients',
          helper: 'Review ingredient labels and cross-contact risks yourself.',
          child: AppPickerField(
            value: p.excludedIngredients.isEmpty
                ? 'No exclusions added · Edit'
                : 'Excluding ${p.excludedIngredients.join(', ')} · Edit',
            trailing: null,
            semanticLabel: 'Edit excluded ingredients',
            onTap: () => _editExclusions(p),
          ),
        ),
        section(
          'Cuisine or food preference',
          ChoiceChips<String?>(
            options: const [null, ...MealPreferences.cuisineOptions],
            selected: p.cuisine,
            labelOf: (x) => x ?? 'Any cuisine',
            onSelected: (x) =>
                _set(p.copyWith(cuisine: x, clearCuisine: x == null)),
          ),
        ),
        Column(
          children: [
            AppButton(
              label: showLabel,
              loading: _saving,
              onPressed: () => _save(p),
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              label: 'Reset preferences',
              onPressed:
                  _saving ? null : () => _set(const MealPreferences()),
            ),
          ],
        ),
      ],
    );
  }
}

/// Add / remove excluded ingredient words. Returns the edited list.
class _ExclusionsSheet extends StatefulWidget {
  const _ExclusionsSheet({required this.initial});
  final List<String> initial;

  @override
  State<_ExclusionsSheet> createState() => _ExclusionsSheetState();
}

class _ExclusionsSheetState extends State<_ExclusionsSheet> {
  late final List<String> _items = [...widget.initial];
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add() {
    final v = _ctrl.text.trim().toLowerCase();
    if (v.isEmpty) return;
    setState(() {
      if (!_items.contains(v)) _items.add(v);
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          22, 0, 22, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exclude ingredients',
                style: AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Recipes containing these words are hidden. This is a '
              'preference, not an allergy guarantee.',
              style: AppTypography.body.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _ctrl,
                    hint: 'e.g. peanut',
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    semanticLabel: 'Ingredient to exclude',
                  ),
                ),
                const SizedBox(width: 10),
                RoundIconButton(
                  icon: LucideIcons.plus,
                  semanticLabel: 'Add exclusion',
                  square: true,
                  size: 50,
                  onPressed: _add,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_items.isEmpty)
              Text('No exclusions added',
                  style: AppTypography.body.copyWith(color: c.textMuted))
            else
              ChipWrap(
                children: [
                  for (final e in _items)
                    InputChip(
                      label: Text(e,
                          style: AppTypography.body
                              .copyWith(color: c.textPrimary)),
                      backgroundColor: c.surface,
                      side: BorderSide(color: c.border),
                      shape: const StadiumBorder(),
                      deleteIcon: Icon(LucideIcons.x,
                          size: 16, color: c.textMuted),
                      deleteButtonTooltipMessage: 'Remove $e',
                      onDeleted: () => setState(() => _items.remove(e)),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Done',
              onPressed: () {
                final pending = _ctrl.text.trim().toLowerCase();
                if (pending.isNotEmpty && !_items.contains(pending)) {
                  _items.add(pending);
                }
                Navigator.of(context).pop(_items);
              },
            ),
          ],
        ),
      ),
    );
  }
}
