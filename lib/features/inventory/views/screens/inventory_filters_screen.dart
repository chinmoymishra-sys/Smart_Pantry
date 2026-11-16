import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../controllers/inventory_controller.dart';

/// Edits a local copy of the inventory filter; nothing is applied until
/// "Show N items".
class InventoryFiltersScreen extends ConsumerStatefulWidget {
  const InventoryFiltersScreen({super.key});

  @override
  ConsumerState<InventoryFiltersScreen> createState() =>
      _InventoryFiltersScreenState();
}

class _InventoryFiltersScreenState
    extends ConsumerState<InventoryFiltersScreen> {
  late InventoryFilter _f = ref.read(inventoryFilterProvider);

  void _update(InventoryFilter f) => setState(() => _f = f);

  void _apply() {
    ref.read(inventoryFilterProvider.notifier).set(_f);
    context.pop();
  }

  void _reset() => _update(InventoryFilter(query: _f.query));

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(inventoryProvider).value ?? const [];
    final count = _f.apply(items).length;

    return AppPage(
      title: 'Find what you need',
      subtitle: 'Inventory filters · preview before applying',
      children: [
        _Section(
          title: 'Storage',
          child: ChoiceChips<StorageLocation?>(
            options: const [null, ...StorageLocation.values],
            selected: _f.storage,
            labelOf: (s) => s?.label ?? 'All',
            onSelected: (s) =>
                _update(_f.copyWith(storage: s, clearStorage: s == null)),
          ),
        ),
        _Section(
          title: 'Category',
          child: ChoiceChips<FoodCategory?>(
            options: const [null, ...FoodCategory.values],
            selected: _f.category,
            labelOf: (v) => v?.label ?? 'All foods',
            onSelected: (v) =>
                _update(_f.copyWith(category: v, clearCategory: v == null)),
          ),
        ),
        _Section(
          title: 'Food state',
          child: ChoiceChips<FoodState?>(
            options: const [null, ...FoodState.values],
            selected: _f.foodState,
            labelOf: (v) => v?.label ?? 'Any',
            onSelected: (v) =>
                _update(_f.copyWith(foodState: v, clearFoodState: v == null)),
          ),
        ),
        _Section(
          title: 'Condition / freshness',
          caption: 'Condition labels reflect a user’s recorded assessment, '
              'never a safety judgment from a photo.',
          child: ChoiceChips<Condition?>(
            options: const [null, ...Condition.values],
            selected: _f.condition,
            labelOf: (v) => v?.label ?? 'Any condition',
            onSelected: (v) =>
                _update(_f.copyWith(condition: v, clearCondition: v == null)),
          ),
        ),
        _Section(
          title: 'Recorded expiry',
          child: ChoiceChips<DateFilter>(
            options: DateFilter.values,
            selected: _f.date,
            labelOf: (v) => v.label,
            onSelected: (v) => _update(_f.copyWith(date: v)),
          ),
        ),
        _Section(
          title: 'Stock',
          child: ChoiceChips<StockFilter>(
            options: StockFilter.values,
            selected: _f.stock,
            labelOf: (v) => v.label,
            onSelected: (v) => _update(_f.copyWith(stock: v)),
          ),
        ),
        _Section(
          title: 'Sort by',
          caption: 'Quantity sorting groups compatible units. Undated items '
              'come last in expiry sorting.',
          child: ChoiceChips<InventorySort>(
            options: InventorySort.values,
            selected: _f.sort,
            labelOf: (v) => v.label,
            onSelected: (v) => _update(_f.copyWith(sort: v)),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Show $count ${count == 1 ? 'item' : 'items'}',
              onPressed: _apply,
            ),
            const SizedBox(height: 20),
            AppButton.secondary(
              label: 'Reset all filters',
              onPressed: _reset,
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.caption});

  final String title;
  final Widget child;
  final String? caption;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(title),
          const SizedBox(height: 20),
          child,
          if (caption != null) ...[
            const SizedBox(height: 16),
            Footnote(caption!),
          ],
        ],
      );
}
