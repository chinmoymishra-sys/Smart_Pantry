import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_pantry/app.dart';
import 'package:smart_pantry/core/navigation/routes.dart';
import 'package:smart_pantry/core/enums/pantry_enums.dart';
import 'package:smart_pantry/core/utils/units.dart';
import 'package:smart_pantry/data/database/app_database.dart';
import 'package:smart_pantry/data/repositories/sqlite_capture_repository.dart';
import 'package:smart_pantry/features/capture/models/capture_models.dart';
import 'package:smart_pantry/providers/repository_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/database_test.dart' show FakePhotos;

Future<AppDatabase> _openDb() => AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);

Future<void> _pumpApp(WidgetTester tester, AppDatabase db,
    {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      photoStorageProvider.overrideWithValue(FakePhotos()),
    ],
    child: const SmartPantryApp(),
  ));
  await _settle(tester);
}

/// Pumps until async SQLite work settles (no infinite animations here).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _seed(AppDatabase db) async {
  final cap = SqliteCaptureRepository(db.db, FakePhotos());
  final d = await cap.createDraft(method: CaptureMethod.manual);
  DetectionDraft det(String name, double q, PantryUnit u, StorageLocation s,
          {DateTime? expiry}) =>
      DetectionDraft(
        id: 'd-$name',
        captureDraftId: d.id,
        name: name,
        category: FoodCategory.vegetable,
        quantity: q,
        unit: u,
        quantitySource: QuantitySource.userEntered,
        foodState: FoodState.raw,
        storage: s,
        expiryDate: expiry,
        createdAt: DateTime.now(),
      );
  final now = DateTime.now();
  await cap.commitDraft(d.copyWith(detections: [
    det('Spinach', 150, PantryUnit.g, StorageLocation.fridge,
        expiry: DateTime(now.year, now.month, now.day + 2)),
    det('Tomatoes', 4, PantryUnit.pieces, StorageLocation.fridge),
    det('Chickpeas', 2, PantryUnit.tins, StorageLocation.pantry),
    det('Olive oil', 50, PantryUnit.ml, StorageLocation.pantry),
  ]));
}

void main() {
  testWidgets('first use: overview empty state and tab navigation',
      (tester) async {
    final db = await _openDb();
    await _pumpApp(tester, db);

    expect(find.text('Smart Pantry'), findsOneWidget);
    expect(find.text('A fresh start for your pantry'), findsOneWidget);

    await tester.tap(find.text('Inventory').last);
    await _settle(tester);
    expect(find.text('Your inventory'), findsOneWidget);

    await tester.tap(find.text('Meals').last);
    await _settle(tester);
    expect(find.text('What can I cook?'), findsOneWidget);

    await tester.tap(find.text('Scan/Add').last);
    await _settle(tester);
    expect(find.text('What’s coming home?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await db.close();
  });

  testWidgets('manual add saves only after explicit confirmation',
      (tester) async {
    final db = await _openDb();
    await _pumpApp(tester, db);

    await tester.tap(find.text('Scan/Add').last);
    await _settle(tester);
    await tester.tap(find.text('Add manually'));
    await _settle(tester);
    expect(find.text('Add it your way'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Carrots');
    await tester.enterText(fields.at(1), '2');
    await tester.pump();

    final next = find.text('Next: dates, condition & notes');
    await tester.scrollUntilVisible(next, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(next);
    await tester.pump();
    await tester.tap(next);
    await _settle(tester);
    expect(find.text('A few optional details'), findsOneWidget);

    // Nothing is in inventory yet.
    final rows = await db.db.query('pantry_items');
    expect(rows, isEmpty);

    final confirm = find.textContaining('Confirm & add');
    await tester.scrollUntilVisible(confirm, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(confirm);
    await tester.pump();
    await tester.tap(confirm);
    await _settle(tester);

    final saved = await db.db.query('pantry_items');
    expect(saved.single['name'], 'Carrots');
    expect(saved.single['quality_condition'], 'not_assessed');
    expect(saved.single['expiry_date'], isNull);

    await tester.tap(find.text('View inventory').last);
    await _settle(tester);
    expect(find.text('Carrots'), findsWidgets);
    expect(tester.takeException(), isNull);
    await db.close();
  });

  testWidgets('meals match confirmed inventory; cooking start keeps pantry',
      (tester) async {
    final db = await _openDb();
    await _seed(db);
    await _pumpApp(tester, db);

    await tester.tap(find.text('Meals').last);
    await _settle(tester);
    final skilletAvail = find.text('4 of 4 required ingredients available');
    await tester.scrollUntilVisible(skilletAvail, 200,
        scrollable: find.byType(Scrollable).first);
    expect(skilletAvail, findsOneWidget);

    GoRouter.of(tester.element(skilletAvail))
        .push(Routes.recipe('spinach-chickpea-skillet'));
    await _settle(tester);
    expect(find.text('Easy · 2 servings'), findsOneWidget);
    final start = find.text('Start cooking');
    await tester.scrollUntilVisible(start, 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(start);
    await tester.pump();
    await tester.tap(start);
    await _settle(tester);
    expect(find.text('Prep the ingredients'), findsWidgets);

    final spinach = await db.db
        .query('pantry_items', where: 'name = ?', whereArgs: ['Spinach']);
    expect(spinach.single['quantity'], 150,
        reason: 'starting cooking never deducts');
    expect(tester.takeException(), isNull);
    await db.close();
  });

  testWidgets('inventory and item detail render in dark mode', (tester) async {
    final db = await _openDb();
    await _seed(db);
    await _pumpApp(tester, db, brightness: Brightness.dark);

    await tester.tap(find.text('Inventory').last);
    await _settle(tester);
    expect(find.text('Spinach'), findsWidgets);
    await tester.tap(find.text('Spinach').last);
    await _settle(tester);
    expect(find.text('Consume / use some'), findsOneWidget);
    expect(find.text('Not assessed'), findsWidgets);
    expect(tester.takeException(), isNull);
    await db.close();
  });
}
