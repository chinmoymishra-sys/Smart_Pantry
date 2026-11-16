import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/units.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../controllers/inventory_controller.dart';
import '../../models/pantry_item.dart';

/// Inventory tab root: storage summary, quick filters, search and the
/// grouped list of confirmed items.
class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search =
        TextEditingController(text: ref.read(inventoryFilterProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  InventoryFilterController get _filters =>
      ref.read(inventoryFilterProvider.notifier);

  void _toggleStorage(StorageLocation s) {
    final current = ref.read(inventoryFilterProvider).storage;
    _filters.setStorage(current == s ? null : s);
  }

  void _toggleDate(DateFilter d) {
    final f = ref.read(inventoryFilterProvider);
    _filters.set(f.copyWith(date: f.date == d ? DateFilter.any : d));
  }

  void _toggleStock(StockFilter s) {
    final f = ref.read(inventoryFilterProvider);
    _filters.set(f.copyWith(stock: f.stock == s ? StockFilter.all : s));
  }

  void _resetAll() {
    final f = ref.read(inventoryFilterProvider);
    _search.clear();
    _filters.set(InventoryFilter(sort: f.sort));
  }

  Future<void> _pickSort() async {
    final f = ref.read(inventoryFilterProvider);
    final picked = await showOptionSheet<InventorySort>(
      context,
      title: 'Sort by',
      options: InventorySort.values,
      labelOf: (s) => s.label,
      selected: f.sort,
    );
    if (picked != null && mounted) {
      _filters.set(ref.read(inventoryFilterProvider).copyWith(sort: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inventoryProvider);
    final filter = ref.watch(inventoryFilterProvider);

    if (!async.hasValue) {
      return AppPage(
        title: 'Your inventory',
        showBack: false,
        children: [
          if (async.hasError)
            ErrorStateView(
              error: async.error!,
              onRetry: () => ref.invalidate(inventoryProvider),
            )
          else
            const LoadingView(label: 'Loading your inventory…'),
        ],
      );
    }

    final items = async.value!;
    final summary = InventorySummary.of(items);

    if (items.isEmpty) {
      return AppPage(
        title: 'Your inventory',
        subtitle: '0 unique items',
        showBack: false,
        children: [
          StateCard(
            icon: LucideIcons.shoppingBasket,
            title: 'A fresh start for your pantry',
            body: '0 items · Fridge 0 · Freezer 0 · Pantry 0. Add your first '
                'food to see storage summaries, date reminders and meal ideas.',
            actions: [
              AppButton(
                label: 'Scan your first groceries',
                icon: LucideIcons.camera,
                onPressed: () => context.push(Routes.camera),
              ),
              AppButton.secondary(
                label: 'Start with manual entry',
                onPressed: () => context.push(Routes.manualAdd),
              ),
            ],
          ),
        ],
      );
    }

    final results = filter.apply(items);
    final showCustom = summary.custom > 0 || filter.storage == StorageLocation.custom;

    return AppPage(
      title: 'Your inventory',
      subtitle:
          '${summary.total} unique ${summary.total == 1 ? 'item' : 'items'} · updated just now',
      showBack: false,
      children: [
        Row(
          children: [
            Expanded(
              child: _StorageTile(
                count: summary.freezer,
                label: 'Freezer',
                selected: filter.storage == StorageLocation.freezer,
                onTap: () => _toggleStorage(StorageLocation.freezer),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _StorageTile(
                count: summary.fridge,
                label: 'Fridge',
                selected: filter.storage == StorageLocation.fridge,
                onTap: () => _toggleStorage(StorageLocation.fridge),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _StorageTile(
                count: summary.pantry,
                label: 'Pantry',
                selected: filter.storage == StorageLocation.pantry,
                onTap: () => _toggleStorage(StorageLocation.pantry),
              ),
            ),
          ],
        ),
        ChipWrap(
          children: [
            _QuickPill(
              label: '${summary.useSoon.length} use soon',
              active: filter.date == DateFilter.within3Days,
              onTap: () => _toggleDate(DateFilter.within3Days),
            ),
            _QuickPill(
              label: '${summary.lowStock.length} low stock',
              active: filter.stock == StockFilter.low,
              onTap: () => _toggleStock(StockFilter.low),
            ),
            _QuickPill(
              label: '${summary.out.length} out',
              active: filter.stock == StockFilter.out,
              onTap: () => _toggleStock(StockFilter.out),
            ),
          ],
        ),
        AppTextField(
          controller: _search,
          hint: 'Search food by name',
          prefixIcon: LucideIcons.search,
          semanticLabel: 'Search food by name',
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.none,
          onChanged: _filters.setQuery,
        ),
        Row(
          children: [
            Expanded(
              child: AppButton.secondary(
                label: filter.activeCount > 0
                    ? 'Filters · ${filter.activeCount}'
                    : 'Filters',
                icon: LucideIcons.slidersHorizontal,
                onPressed: () => context.push(Routes.inventoryFilters),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: AppButton.secondary(
                label: 'Sort: ${filter.sort.shortLabel}',
                icon: LucideIcons.arrowDownWideNarrow,
                onPressed: _pickSort,
              ),
            ),
          ],
        ),
        ChipWrap(
          children: [
            AppChip(
              label: 'All storage',
              selected: filter.storage == null,
              onTap: () => _filters.setStorage(null),
            ),
            for (final s in [
              StorageLocation.fridge,
              StorageLocation.freezer,
              StorageLocation.pantry,
              if (showCustom) StorageLocation.custom,
            ])
              AppChip(
                label: s.label,
                selected: filter.storage == s,
                onTap: () => _filters.setStorage(s),
              ),
          ],
        ),
        if (results.isEmpty)
          StateCard(
            icon: LucideIcons.searchX,
            title: 'Nothing matches these filters',
            body: filter.query.trim().isNotEmpty
                ? 'No items match “${filter.query.trim()}” with the current '
                    'filters. Your inventory is still here; try a wider search.'
                : 'No items match the current filters. Your inventory is '
                    'still here; try a wider search.',
            actions: [
              AppButton.secondary(
                label: 'Reset all filters',
                onPressed: _resetAll,
              ),
            ],
          )
        else
          for (final group in _groupByStorage(results))
            _StorageGroup(title: group.$1, items: group.$2),
        const Footnote(
          'Use-soon reminders: stored dates within 3 days. Quality and safety '
          'are not assessed. Quantities remain in their own units.',
        ),
        AppButton(
          label: 'Add food',
          icon: LucideIcons.plus,
          onPressed: () => context.go(Routes.scan),
        ),
      ],
    );
  }

  /// Fridge, Freezer, Pantry, then each custom location by name. Order of
  /// items inside a group follows the active sort.
  static List<(String, List<PantryItem>)> _groupByStorage(
      List<PantryItem> items) {
    final groups = <(String, List<PantryItem>)>[];
    for (final loc in [
      StorageLocation.fridge,
      StorageLocation.freezer,
      StorageLocation.pantry,
    ]) {
      final list = items.where((i) => i.storage == loc).toList();
      if (list.isNotEmpty) groups.add((loc.label, list));
    }
    final custom =
        items.where((i) => i.storage == StorageLocation.custom).toList();
    final names = custom.map((i) => i.storageLabel).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final n in names) {
      groups.add((n, custom.where((i) => i.storageLabel == n).toList()));
    }
    return groups;
  }
}

class _StorageTile extends StatelessWidget {
  const _StorageTile({
    required this.count,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int count;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: '$count in $label',
      excludeSemantics: true,
      child: Material(
        color: c.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(
              color: selected ? c.textPrimary : Colors.transparent),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: AppTypography.pageTitle
                        .copyWith(color: c.textPrimary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: AppTypography.caption.copyWith(color: c.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Status pill that doubles as a quick filter; active pills show a check.
class _QuickPill extends StatelessWidget {
  const _QuickPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => active
      ? AppChip(label: label, selected: true, onTap: onTap)
      : Semantics(
          button: true,
          selected: false,
          child: StatusPill(label: label, onTap: onTap),
        );
}

class _StorageGroup extends StatelessWidget {
  const _StorageGroup({required this.title, required this.items});

  final String title;
  final List<PantryItem> items;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeading(
              '$title · ${items.length} ${items.length == 1 ? 'item' : 'items'}'),
          const SizedBox(height: 4),
          for (final item in items) _InventoryRow(item: item),
        ],
      );
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item});

  final PantryItem item;

  /// Meta line and whether it should be shown in the warning colour.
  (String, bool) _meta() {
    final state = item.foodState.label;
    if (item.isUnavailable) return ('Unavailable · excluded from meals', false);
    if (item.isOut) return ('Out of stock', true);
    if (item.isUseSoon || item.isPastDate) {
      return ('$state · ${item.dateSummary}', true);
    }
    if (item.isLowStock) {
      final t = formatQuantity(
          item.lowStockThreshold!, item.lowStockUnit ?? item.unit);
      return ('Low stock · threshold $t', true);
    }
    final pkg = item.packageContentLabel;
    if (pkg != null && item.expiryDate == null) return ('$state · $pkg', false);
    return ('$state · ${item.dateSummary}', false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (meta, warn) = _meta();
    return Semantics(
      button: true,
      label: '${item.name}, ${item.quantityLabel}. $meta',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(Routes.item(item.id)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 71),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.name,
                        style: AppTypography.titleStrong
                            .copyWith(color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      style: AppTypography.caption
                          .copyWith(color: warn ? c.warning : c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(item.quantityShortLabel,
                  style: AppTypography.subtitle.copyWith(color: c.textPrimary)),
              const SizedBox(width: 10),
              Icon(LucideIcons.chevronRight, size: 18, color: c.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
