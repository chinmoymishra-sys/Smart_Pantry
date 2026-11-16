// Opt-in visual comparison tool. Renders key screens with the real Inter and
// Lucide fonts so they can be compared side-by-side with the design frames.
//
//   SCREENSHOT_DIR=/some/dir flutter test test/visual
//
// Skipped during normal `flutter test` runs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:smart_pantry/app.dart';
import 'package:smart_pantry/core/enums/pantry_enums.dart';
import 'package:smart_pantry/core/navigation/routes.dart';
import 'package:smart_pantry/core/utils/dates.dart';
import 'package:smart_pantry/core/utils/units.dart';
import 'package:smart_pantry/data/database/app_database.dart';
import 'package:smart_pantry/data/repositories/sqlite_capture_repository.dart';
import 'package:smart_pantry/features/capture/models/capture_models.dart';
import 'package:smart_pantry/providers/repository_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/database_test.dart' show FakePhotos;

final _outDir = Platform.environment['SCREENSHOT_DIR'];

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
  }
  await inter.load();
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'));
  await lucide.load();
}

Future<void> _seedDesignPantry(AppDatabase db) async {
  final cap = SqliteCaptureRepository(db.db, FakePhotos());
  final d = await cap.createDraft(method: CaptureMethod.manual);
  var i = 0;
  DetectionDraft det(String name, double q, PantryUnit u, StorageLocation s,
      FoodState st, FoodCategory c,
      {DateTime? exp, DateType dt = DateType.useBy, double? low, double? pkg}) {
    return DetectionDraft(
      id: 'd${i++}',
      captureDraftId: d.id,
      name: name,
      category: c,
      quantity: q,
      unit: u,
      quantitySource: u.kind == UnitKind.count
          ? QuantitySource.userEntered
          : QuantitySource.userMeasured,
      foodState: st,
      storage: s,
      expiryDate: exp,
      dateType: dt,
      lowStockThreshold: low,
      packageContentQuantity: pkg,
      packageContentUnit: pkg == null ? null : PantryUnit.g,
      purchaseDate: DateTime(2026, 11, 6),
      dateAdded: DateTime(2026, 11, 6),
      notes: name == 'Spinach' ? 'Washed weight. For lunch this week.' : null,
      createdAt: DateTime.now(),
      sortOrder: i,
    );
  }

  const f = StorageLocation.fridge, z = StorageLocation.freezer, pa = StorageLocation.pantry;
  await cap.commitDraft(d.copyWith(detections: [
    det('Spinach', 150, PantryUnit.g, f, FoodState.raw, FoodCategory.vegetable,
        exp: DateTime(2026, 11, 8)),
    det('Plain yogurt', 400, PantryUnit.g, f, FoodState.packaged, FoodCategory.dairy,
        exp: DateTime(2026, 11, 9), dt: DateType.bestBefore),
    det('Tomatoes', 4, PantryUnit.pieces, f, FoodState.raw, FoodCategory.vegetable,
        exp: DateTime(2026, 11, 11)),
    det('Milk', 1, PantryUnit.l, f, FoodState.packaged, FoodCategory.dairy,
        exp: DateTime(2026, 11, 12)),
    det('Paneer', 200, PantryUnit.g, f, FoodState.packaged, FoodCategory.dairy,
        exp: DateTime(2026, 11, 14)),
    det('Eggs', 6, PantryUnit.pieces, f, FoodState.raw, FoodCategory.other,
        exp: DateTime(2026, 11, 18), dt: DateType.bestBefore),
    det('Green peas', 300, PantryUnit.g, z, FoodState.frozen, FoodCategory.vegetable),
    det('Blueberries', 250, PantryUnit.g, z, FoodState.frozen, FoodCategory.fruit),
    det('Chickpeas', 2, PantryUnit.tins, pa, FoodState.packaged, FoodCategory.packaged,
        pkg: 240),
    det('Oats', 500, PantryUnit.g, pa, FoodState.dried, FoodCategory.grain),
    det('Rice', 1, PantryUnit.kg, pa, FoodState.dried, FoodCategory.grain),
    det('Olive oil', 50, PantryUnit.ml, pa, FoodState.packaged, FoodCategory.packaged,
        low: 60),
  ]));
}

void main() {
  final skip = _outDir == null ? 'Set SCREENSHOT_DIR to render screens' : null;

  final shots = <String, String>{
    'overview': Routes.overview,
    'scan-add': Routes.scan,
    'inventory-list': Routes.inventory,
    'inventory-filters': Routes.inventoryFilters,
    'what-can-i-cook': Routes.meals,
    'meal-filters': Routes.mealFilters,
    'recipe-detail': Routes.recipe('spinach-chickpea-skillet'),
    'recipe-instructions': Routes.recipeInstructions('spinach-chickpea-skillet'),
    'manual-add': Routes.manualAdd,
    'barcode-unknown': Routes.barcodeResult('8900000000123'),
    'history': Routes.history,
  };

  for (final dark in [false, true]) {
    for (final e in shots.entries) {
      testWidgets('${e.key}${dark ? ' (dark)' : ''}', skip: skip != null,
          (tester) async {
        AppDates.clock = () => DateTime(2026, 11, 6, 12);
        await tester.runAsync(_loadFonts);
        final db = await AppDatabase.open(
            factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
        await _seedDesignPantry(db);
        tester.view.physicalSize = const Size(402, 2600);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue =
            dark ? Brightness.dark : Brightness.light;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              photoStorageProvider.overrideWithValue(FakePhotos()),
            ],
            child: const SmartPantryApp(),
          ),
        ));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        final ctx = tester.element(find.byType(Scaffold).first);
        if (e.value != Routes.overview) {
          GoRouter.of(ctx).go(e.value);
        }
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        // Precache images so photos render.
        await tester.runAsync(() async {
          for (final el in find.byType(Image).evaluate()) {
            final img = el.widget as Image;
            await precacheImage(img.image, el);
          }
        });
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final ui.Image image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(p.join(_outDir!, '${e.key}${dark ? '_dark' : ''}.png'));
          await file.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        await db.close();
      });
    }
  }
}
