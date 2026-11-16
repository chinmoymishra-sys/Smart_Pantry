import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/units.dart';
import '../../../providers/repository_providers.dart';
import '../../capture/models/capture_models.dart';
import '../../cooking/models/cooking_models.dart';
import '../../inventory/controllers/inventory_controller.dart';
import '../../inventory/models/inventory_transaction.dart';

final scanRecordsProvider = FutureProvider<List<ScanRecord>>(
    (ref) => ref.watch(captureRepositoryProvider).getScanRecords());

final cookingHistoryProvider = FutureProvider<List<CookingSession>>(
    (ref) => ref.watch(cookingRepositoryProvider).getHistory());

enum ActivityFilter {
  all('All activity'),
  added('Food added'),
  cooking('Cooking'),
  scans('Scans');

  const ActivityFilter(this.label);
  final String label;
}

enum ActivityKind { cooking, scan, added, change }

class ActivityEntry {
  const ActivityEntry({
    required this.kind,
    required this.when,
    required this.title,
    required this.lines,
    this.scan,
    this.session,
    this.itemId,
  });

  final ActivityKind kind;
  final DateTime when;
  final String title;
  final List<String> lines;
  final ScanRecord? scan;
  final CookingSession? session;
  final String? itemId;
}

class ActivityFilterController extends Notifier<ActivityFilter> {
  @override
  ActivityFilter build() => ActivityFilter.all;
  void set(ActivityFilter f) => state = f;
}

final activityFilterProvider =
    NotifierProvider<ActivityFilterController, ActivityFilter>(
        ActivityFilterController.new);

String _describe(InventoryTransaction t) {
  String q(double? v) => v == null ? '' : formatQuantity(v.abs(), t.unit);
  switch (t.type) {
    case TransactionType.itemAdded:
      return '${t.itemName} added';
    case TransactionType.quantityConsumed:
      return '${t.itemName} · used ${q(t.quantityDelta)}';
    case TransactionType.quantitySet:
      return '${t.itemName} · quantity set to ${q(t.quantityAfter)}';
    case TransactionType.moved:
      return '${t.itemName} moved · ${t.notes ?? ''}';
    case TransactionType.markedFinished:
      return '${t.itemName} marked finished';
    case TransactionType.discarded:
      return '${t.itemName} discarded${t.reason == null ? '' : ' · ${t.reason}'}';
    case TransactionType.markedUnavailable:
      return '${t.itemName} marked unavailable';
    case TransactionType.markedAvailable:
      return '${t.itemName} available again';
    case TransactionType.itemRemoved:
      return '${t.itemName} removed';
    case TransactionType.itemEdited:
      return '${t.itemName} details edited';
    case TransactionType.cookingDeduction:
      return '${t.itemName} · used ${q(t.quantityDelta)} cooking';
  }
}

/// Household activity derived from persisted records (never stored twice).
final activityProvider = FutureProvider<List<ActivityEntry>>((ref) async {
  final txs = await ref.watch(inventoryTransactionsProvider.future);
  final scans = await ref.watch(scanRecordsProvider.future);
  final sessions = await ref.watch(cookingHistoryProvider.future);
  final cooking = ref.watch(cookingRepositoryProvider);

  final entries = <ActivityEntry>[];
  for (final s in sessions) {
    final usage = await cooking.getUsage(s.id);
    final used = usage.where((u) => !u.isSkipped && u.actualQuantity != null);
    final parts = used
        .map((u) =>
            '${u.ingredientName} −${formatQuantity(u.actualQuantity!, u.actualUnit!)}')
        .toList();
    final lines = <String>[
      '${s.servings} serving${s.servings == 1 ? '' : 's'} · '
          '${s.status == CookingStatus.completed ? 'deductions confirmed' : 'pantry unchanged'}',
    ];
    for (var i = 0; i < parts.length; i += 2) {
      lines.add(parts.skip(i).take(2).join(' · '));
    }
    entries.add(ActivityEntry(
      kind: ActivityKind.cooking,
      when: s.completedAt ?? s.startedAt,
      title: 'Cooked ${s.recipeName[0].toLowerCase()}${s.recipeName.substring(1)}',
      lines: lines,
      session: s,
    ));
  }
  for (final sc in scans) {
    final names = sc.itemNames;
    final joined = names.length <= 1
        ? names.join()
        : '${names.take(names.length - 1).join(', ')} and ${names.last}';
    entries.add(ActivityEntry(
      kind: ActivityKind.scan,
      when: sc.createdAt,
      title:
          '${sc.confirmedItemCount} item${sc.confirmedItemCount == 1 ? '' : 's'} added after review',
      lines: [if (joined.isNotEmpty) '${joined[0].toUpperCase()}${joined.substring(1).toLowerCase()}'],
      scan: sc,
    ));
  }
  for (final t in txs) {
    // Cooking deductions and scan additions are summarised above.
    if (t.type == TransactionType.cookingDeduction) continue;
    if (t.type == TransactionType.itemAdded && t.relatedScanId != null) continue;
    final isAdd = t.type == TransactionType.itemAdded;
    entries.add(ActivityEntry(
      kind: isAdd ? ActivityKind.added : ActivityKind.change,
      when: t.createdAt,
      title: _describe(t),
      lines: [
        if (isAdd && t.quantityAfter != null) formatQuantity(t.quantityAfter!, t.unit),
      ],
      itemId: t.pantryItemId,
    ));
  }
  entries.sort((a, b) => b.when.compareTo(a.when));
  return entries;
});

final filteredActivityProvider =
    Provider<AsyncValue<List<ActivityEntry>>>((ref) {
  final f = ref.watch(activityFilterProvider);
  return ref.watch(activityProvider).whenData((all) => switch (f) {
        ActivityFilter.all => all,
        ActivityFilter.added => all
            .where((e) =>
                e.kind == ActivityKind.added || e.kind == ActivityKind.scan)
            .toList(),
        ActivityFilter.cooking =>
          all.where((e) => e.kind == ActivityKind.cooking).toList(),
        ActivityFilter.scans =>
          all.where((e) => e.kind == ActivityKind.scan).toList(),
      });
});

class HistoryController {
  HistoryController(this.ref);
  final Ref ref;

  Future<void> deleteScanRecord(String scanId) async {
    await ref.read(captureRepositoryProvider).deleteScanRecord(scanId);
    ref.invalidate(scanRecordsProvider);
  }
}

final historyControllerProvider = Provider<HistoryController>(HistoryController.new);
