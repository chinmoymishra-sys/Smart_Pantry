/// Quantity and unit rules.
///
/// * Quantities are always stored together with an explicit unit.
/// * Only units in the same [UnitKind] can be converted (g↔kg, ml↔L).
/// * Count/package units are never converted to weight or volume.
library;

enum UnitKind { weight, volume, count }

enum PantryUnit {
  g('g', 'g', UnitKind.weight, 1),
  kg('kg', 'kg', UnitKind.weight, 1000),
  ml('ml', 'ml', UnitKind.volume, 1),
  l('L', 'L', UnitKind.volume, 1000),
  pieces('pieces', 'pcs', UnitKind.count, 1),
  packets('packets', 'packets', UnitKind.count, 1),
  boxes('boxes', 'boxes', UnitKind.count, 1),
  tins('tins', 'tins', UnitKind.count, 1),
  slices('slices', 'slices', UnitKind.count, 1),
  servings('servings', 'servings', UnitKind.count, 1);

  const PantryUnit(this.dbValue, this.shortLabel, this.kind, this.toBase);

  /// Stored value and long label (e.g. "pieces").
  final String dbValue;

  /// Compact label used in inventory rows (e.g. "pcs").
  final String shortLabel;
  final UnitKind kind;

  /// Multiplier to the kind's base unit (g or ml). Count units are 1 and are
  /// only comparable with the *same* count unit.
  final double toBase;

  String get label => dbValue;

  static PantryUnit fromDb(String? raw) {
    for (final u in values) {
      if (u.dbValue == raw) return u;
    }
    return PantryUnit.pieces;
  }

  /// Units offered in the design's unit chips.
  static const selectable = [
    g,
    kg,
    ml,
    l,
    pieces,
    packets,
    boxes,
    tins,
    slices,
    servings,
  ];

  bool isCompatibleWith(PantryUnit other) {
    if (this == other) return true;
    if (kind == UnitKind.count || other.kind == UnitKind.count) return false;
    return kind == other.kind;
  }
}

class UnitMismatchException implements Exception {
  UnitMismatchException(this.from, this.to);
  final PantryUnit from;
  final PantryUnit to;
  @override
  String toString() =>
      'Cannot convert ${from.dbValue} to ${to.dbValue}: units are not compatible.';
}

/// Converts [value] from [from] to [to]. Throws [UnitMismatchException] for
/// incompatible units — callers must never silently combine them.
double convertQuantity(double value, PantryUnit from, PantryUnit to) {
  if (from == to) return value;
  if (!from.isCompatibleWith(to)) throw UnitMismatchException(from, to);
  return value * from.toBase / to.toBase;
}

/// Returns null when the units cannot be compared.
double? tryConvertQuantity(double value, PantryUnit from, PantryUnit to) {
  if (!from.isCompatibleWith(to)) return null;
  return convertQuantity(value, from, to);
}

/// Formats a number without trailing zeros: 150 → "150", 0.5 → "0.5".
String formatNumber(double value) {
  if (value == value.roundToDouble()) {
    final i = value.round();
    return i.abs() >= 1000 ? _thousands(i) : '$i';
  }
  final s = value.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String _thousands(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// "150 g", "2 pieces", "1 tin". Singularises count units for exactly 1.
String formatQuantity(double value, PantryUnit unit, {bool short = false}) {
  final n = formatNumber(value);
  if (unit.kind != UnitKind.count) return '$n ${unit.dbValue}';
  var label = short ? unit.shortLabel : unit.dbValue;
  if (value == 1) label = _singular(label);
  return '$n $label';
}

String _singular(String plural) {
  switch (plural) {
    case 'pieces':
    case 'pcs':
      return plural == 'pcs' ? 'pc' : 'piece';
    case 'boxes':
      return 'box';
    default:
      return plural.endsWith('s') ? plural.substring(0, plural.length - 1) : plural;
  }
}

/// Parses user-typed quantities. Rejects negatives and non-numbers.
double? parseQuantity(String raw) {
  final cleaned = raw.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
  return v;
}
