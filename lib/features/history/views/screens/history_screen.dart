import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../../capture/models/capture_models.dart';
import '../../../inventory/controllers/inventory_controller.dart';
import '../../controllers/history_controller.dart';

/// "Today, 8:20" → "8:20" for today's entries, full stamp otherwise.
String _stamp(DateTime when) {
  final d = DateTime(when.year, when.month, when.day);
  return d == AppDates.today() ? AppDates.time(when) : AppDates.activityStamp(when);
}

/// Household activity: food added, cooking sessions and saved scans.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(activityFilterProvider);
    final entries = ref.watch(filteredActivityProvider);

    return AppPage(
      title: 'A little more organized',
      subtitle: '${AppDates.weekdayLong(AppDates.today())} · Activity',
      children: [
        ChoiceChips<ActivityFilter>(
          options: ActivityFilter.values,
          selected: filter,
          labelOf: (f) => f.label,
          onSelected: (f) => ref.read(activityFilterProvider.notifier).set(f),
        ),
        ...entries.when(
          loading: () => [const LoadingView()],
          error: (e, _) => [
            ErrorStateView(
              error: e,
              onRetry: () {
                ref.invalidate(scanRecordsProvider);
                ref.invalidate(cookingHistoryProvider);
                ref.invalidate(inventoryTransactionsProvider);
              },
            ),
          ],
          data: (list) => list.isEmpty
              ? [_EmptyHistory(filter: filter)]
              : _buildCards(list),
        ),
        const InfoCallout(
          title: 'Your record, your choice',
          body: 'Deleting a scan record asks for confirmation. Confirmed '
              'inventory items remain unless you remove them separately.',
        ),
      ],
    );
  }

  /// Cooking and scan entries get their own cards; consecutive simple
  /// added/changed entries are grouped into one card (as in the design).
  List<Widget> _buildCards(List<ActivityEntry> list) {
    final out = <Widget>[];
    var group = <ActivityEntry>[];
    void flush() {
      if (group.isNotEmpty) {
        out.add(_SimpleEntriesCard(entries: group));
        group = <ActivityEntry>[];
      }
    }

    for (final e in list) {
      switch (e.kind) {
        case ActivityKind.cooking:
          flush();
          out.add(_CookingCard(entry: e));
        case ActivityKind.scan:
          flush();
          out.add(_ScanCard(entry: e));
        case ActivityKind.added:
        case ActivityKind.change:
          group.add(e);
      }
    }
    flush();
    return out;
  }
}

class _CookingCard extends StatelessWidget {
  const _CookingCard({required this.entry});
  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final session = entry.session;
    final lines = entry.lines;
    return AppCard(
      onTap: session == null
          ? null
          : () => context.go(Routes.cookDone(session.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.utensils, size: 22, color: c.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: AppTypography.titleStrong
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  [_stamp(entry.when), if (lines.isNotEmpty) lines.first]
                      .join(' · '),
                  style: AppTypography.body.copyWith(color: c.textMuted),
                ),
                for (final l in lines.skip(1)) ...[
                  const SizedBox(height: 4),
                  Text(l, style: AppTypography.body.copyWith(color: c.textPrimary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmDelete(
    BuildContext context, HistoryController history, ScanRecord scan) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Delete this scan record?',
    body: 'This deletes the saved scan photo and its record from this device. '
        'Confirmed inventory items stay in inventory.',
    confirmLabel: 'Delete scan photo & record',
    cancelLabel: 'Keep scan record',
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  try {
    await history.deleteScanRecord(scan.id);
    if (context.mounted) showAppSnack(context, 'Scan photo and record deleted.');
    return true;
  } catch (e) {
    if (context.mounted) showAppSnack(context, friendlyError(e));
    return false;
  }
}

class _ScanCard extends ConsumerWidget {
  const _ScanCard({required this.entry});
  final ActivityEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final scan = entry.scan;
    final subtitle = [_stamp(entry.when), ...entry.lines].join(' · ');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title,
              style: AppTypography.titleStrong.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTypography.body.copyWith(color: c.textMuted)),
          if (scan?.photoPath != null) ...[
            const SizedBox(height: 12),
            FoodImage(
              path: scan!.photoPath,
              height: 142,
              semanticLabel: 'Saved scan photo',
            ),
          ],
          if (scan != null) ...[
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Review saved scan record',
              onPressed: () => _showScanSheet(context, ref, entry, scan),
            ),
            const SizedBox(height: 12),
            AppButton.danger(
              label: 'Delete scan photo & record…',
              onPressed: () =>
                  _confirmDelete(context, ref.read(historyControllerProvider), scan),
            ),
          ],
        ],
      ),
    );
  }

  void _showScanSheet(
      BuildContext context, WidgetRef ref, ActivityEntry entry, ScanRecord scan) {
    final c = context.colors;
    final history = ref.read(historyControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            children: [
              Text('Saved scan record',
                  style:
                      AppTypography.sectionTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 16),
              if (scan.photoPath != null) ...[
                FoodImage(path: scan.photoPath, height: 200),
                const SizedBox(height: 16),
              ] else ...[
                Text('No photo kept for this scan.',
                    style: AppTypography.body.copyWith(color: c.textMuted)),
                const SizedBox(height: 16),
              ],
              DetailRows([
                ('Saved', AppDates.activityStamp(scan.createdAt)),
                ('Method', scan.method.label),
                (
                  'Items confirmed',
                  '${scan.confirmedItemCount}',
                ),
                if (scan.itemNames.isNotEmpty)
                  ('Items', scan.itemNames.join(', ')),
              ]),
              const SizedBox(height: 16),
              const InfoCallout(
                title: 'Confirmed items stay in inventory',
                body: 'Deleting this record removes the photo and scan '
                    'history only.',
              ),
              const SizedBox(height: 16),
              AppButton.danger(
                label: 'Delete scan photo & record…',
                onPressed: () async {
                  final deleted = await _confirmDelete(ctx, history, scan);
                  if (deleted && ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 12),
              AppButton.secondary(
                label: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleEntriesCard extends ConsumerWidget {
  const _SimpleEntriesCard({required this.entries});
  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _simpleEntry(context, ref, entries[i], c),
          ],
        ],
      ),
    );
  }

  Widget _simpleEntry(
      BuildContext context, WidgetRef ref, ActivityEntry e, AppColors c) {
    final id = e.itemId;
    final item = id == null ? null : ref.watch(pantryItemProvider(id));
    final details = [
      _stamp(e.when),
      ...e.lines,
      if (e.kind == ActivityKind.added && item != null) item.storageLabel,
    ].join(' · ');
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e.title,
            style: AppTypography.titleStrong.copyWith(color: c.textPrimary)),
        const SizedBox(height: 4),
        Text(details, style: AppTypography.body.copyWith(color: c.textMuted)),
      ],
    );
    if (item == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.push(Routes.item(item.id)),
      child: SizedBox(width: double.infinity, child: content),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.filter});
  final ActivityFilter filter;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (filter) {
      ActivityFilter.all => (
          'Nothing recorded yet',
          'Food you add, scans you save and meals you cook will appear here.',
        ),
      ActivityFilter.added => (
          'No food added yet',
          'Items you confirm into inventory will appear here.',
        ),
      ActivityFilter.cooking => (
          'No cooking recorded yet',
          'Finished cooking sessions will appear here.',
        ),
      ActivityFilter.scans => (
          'No saved scans',
          'Scan records you keep after review will appear here.',
        ),
    };
    return StateCard(
      overline: 'History · empty',
      icon: LucideIcons.list,
      title: title,
      body: body,
      actions: [
        AppButton(
          label: 'Bring groceries in',
          icon: LucideIcons.plus,
          onPressed: () => context.go(Routes.scan),
        ),
      ],
    );
  }
}
