import 'package:intl/intl.dart';

/// Date helpers. All persisted timestamps are UTC ISO-8601; calendar dates
/// (purchase, expiry, opened) are stored as `yyyy-MM-dd` with no time.
abstract final class AppDates {
  /// Use-soon reminder window from the design ("within 3 days").
  static const useSoonDays = 3;

  static DateTime Function() clock = DateTime.now;

  static DateTime today() {
    final n = clock();
    return DateTime(n.year, n.month, n.day);
  }

  static String nowUtcIso() => clock().toUtc().toIso8601String();

  static String? toDbDate(DateTime? d) =>
      d == null ? null : DateFormat('yyyy-MM-dd').format(d);

  static DateTime? fromDbDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final p = DateTime.tryParse(raw);
    return p == null ? null : DateTime(p.year, p.month, p.day);
  }

  static DateTime? fromDbTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// "6 Nov 2026"
  static String long(DateTime d) => DateFormat('d MMM y').format(d);

  /// "8 Nov"
  static String short(DateTime d) => DateFormat('d MMM').format(d);

  /// "8 November"
  static String dayMonth(DateTime d) => DateFormat('d MMMM').format(d);

  /// "Friday, 6 November"
  static String weekdayLong(DateTime d) => DateFormat('EEEE, d MMMM').format(d);

  /// "8:20" / "12:45"
  static String time(DateTime d) => DateFormat('H:mm').format(d);

  static int daysUntil(DateTime date) =>
      DateTime(date.year, date.month, date.day).difference(today()).inDays;

  /// "in 3 days", "today", "tomorrow", "2 days ago".
  static String relative(DateTime date) {
    final d = daysUntil(date);
    if (d == 0) return 'today';
    if (d == 1) return 'tomorrow';
    if (d == -1) return 'yesterday';
    if (d > 1) return 'in $d days';
    return '${-d} days ago';
  }

  /// "Today, 8:20" / "Yesterday, 18:02" / "4 Nov, 9:10"
  static String activityStamp(DateTime when) {
    final d = DateTime(when.year, when.month, when.day);
    final diff = today().difference(d).inDays;
    final prefix = diff == 0
        ? 'Today'
        : diff == 1
            ? 'Yesterday'
            : short(when);
    return '$prefix, ${time(when)}';
  }
}
