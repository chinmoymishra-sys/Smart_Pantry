import 'package:flutter_test/flutter_test.dart';
import 'package:smart_pantry/core/utils/units.dart';

void main() {
  group('unit conversion', () {
    test('converts compatible weight and volume units', () {
      expect(convertQuantity(1.5, PantryUnit.kg, PantryUnit.g), 1500);
      expect(convertQuantity(250, PantryUnit.ml, PantryUnit.l), 0.25);
    });

    test('never converts count units to weight', () {
      expect(PantryUnit.pieces.isCompatibleWith(PantryUnit.g), isFalse);
      expect(() => convertQuantity(2, PantryUnit.pieces, PantryUnit.g),
          throwsA(isA<UnitMismatchException>()));
      expect(tryConvertQuantity(1, PantryUnit.tins, PantryUnit.g), isNull);
    });

    test('different count units are not interchangeable', () {
      expect(PantryUnit.packets.isCompatibleWith(PantryUnit.boxes), isFalse);
      expect(PantryUnit.tins.isCompatibleWith(PantryUnit.tins), isTrue);
    });

    test('weight and volume are not compatible', () {
      expect(tryConvertQuantity(100, PantryUnit.g, PantryUnit.ml), isNull);
    });
  });

  group('formatting', () {
    test('formats numbers without trailing zeros', () {
      expect(formatNumber(150), '150');
      expect(formatNumber(0.5), '0.5');
      expect(formatNumber(1000), '1,000');
    });

    test('singularises count units for exactly one', () {
      expect(formatQuantity(1, PantryUnit.tins), '1 tin');
      expect(formatQuantity(2, PantryUnit.tins), '2 tins');
      expect(formatQuantity(4, PantryUnit.pieces, short: true), '4 pcs');
      expect(formatQuantity(1, PantryUnit.boxes), '1 box');
      expect(formatQuantity(1, PantryUnit.l), '1 L');
    });
  });

  group('parseQuantity', () {
    test('accepts decimals with comma or dot', () {
      expect(parseQuantity('2,5'), 2.5);
      expect(parseQuantity(' 150 '), 150);
    });

    test('rejects negatives, blanks and junk', () {
      expect(parseQuantity('-3'), isNull);
      expect(parseQuantity(''), isNull);
      expect(parseQuantity('abc'), isNull);
    });
  });
}
