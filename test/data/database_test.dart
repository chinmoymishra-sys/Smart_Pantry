import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:smart_pantry/core/enums/pantry_enums.dart';
import 'package:smart_pantry/core/errors/app_exceptions.dart';
import 'package:smart_pantry/core/utils/units.dart';
import 'package:smart_pantry/data/database/app_database.dart';
import 'package:smart_pantry/data/repositories/sqlite_capture_repository.dart';
import 'package:smart_pantry/data/repositories/sqlite_cooking_repository.dart';
import 'package:smart_pantry/data/repositories/sqlite_pantry_repository.dart';
import 'package:smart_pantry/data/repositories/sqlite_recipe_repository.dart';
import 'package:smart_pantry/data/services/photo_storage.dart';
import 'package:smart_pantry/features/capture/models/capture_models.dart';
import 'package:smart_pantry/features/cooking/models/cooking_models.dart';
import 'package:smart_pantry/features/meals/models/meal_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakePhotos implements PhotoStorage {
  final deleted = <String>[];
  @override
  Future<void> delete(String path) async => deleted.add(path);
  @override
  Future<String> importPhoto(String sourcePath) async => sourcePath;
}

DetectionDraft det(
  String draftId,
  String name,
  double? qty,
  PantryUnit unit, {
  bool confirmed = true,
  StorageLocation storage = StorageLocation.fridge,
  String? mergeTarget,
}) =>
    DetectionDraft(
      id: '$draftId-$name',
      captureDraftId: draftId,
      name: name,
      category: FoodCategory.vegetable,
      quantity: qty,
      unit: unit,
      quantitySource: QuantitySource.userMeasured,
      foodState: FoodState.raw,
      storage: storage,
      isIdentityConfirmed: confirmed,
      mergeTargetItemId: mergeTarget,
      createdAt: DateTime.now(),
    );

void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late FakePhotos photos;
  late SqlitePantryRepository pantry;
  late SqliteCaptureRepository capture;
  late SqliteCookingRepository cooking;

  setUp(() async {
    db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    photos = FakePhotos();
    pantry = SqlitePantryRepository(db.db, photos);
    capture = SqliteCaptureRepository(db.db, photos);
    cooking = SqliteCookingRepository(db.db);
  });
  tearDown(() => db.close());

  Future<CaptureDraft> draftWith(List<DetectionDraft> Function(String id) build,
      {CaptureMethod method = CaptureMethod.camera}) async {
    final d = await capture.createDraft(method: method, photoPath: '/tmp/x.jpg');
    final full = d.copyWith(detections: build(d.id));
    await capture.saveDraft(full);
    return full;
  }

  test('schema version and seeded recipe catalog', () async {
    expect(await db.db.getVersion(), AppDatabase.schemaVersion);
    final recipes = await SqliteRecipeRepository(db.db).getRecipes();
    expect(recipes.length, 4);
    final skillet = recipes.firstWhere((r) => r.id == 'spinach-chickpea-skillet');
    expect(skillet.steps.length, 4);
    expect(skillet.required.length, 4);
    expect(skillet.optional.single.displayQuantity, '½ lemon');
  });

  test('drafts never affect inventory until committed', () async {
    final d = await draftWith((id) => [det(id, 'Spinach', 150, PantryUnit.g)]);
    expect(await pantry.getItems(), isEmpty);
    final reloaded = await capture.loadOpenDraft();
    expect(reloaded!.detections.single.name, 'Spinach');
    final res = await capture.commitDraft(d);
    expect(res.addedCount, 1);
    final items = await pantry.getItems();
    expect(items.single.quantity, 150);
    expect(items.single.condition, Condition.notAssessed);
    expect(items.single.expiryDate, isNull);
    expect(await capture.loadOpenDraft(), isNull);
    expect((await capture.getScanRecords()).single.confirmedItemCount, 1);
    final tx = await pantry.getTransactions();
    expect(tx.single.type, TransactionType.itemAdded);
    expect(tx.single.relatedScanId, res.scanId);
  });

  test('save is blocked while an uncertain identity is unresolved', () async {
    final d = await draftWith((id) => [
          det(id, 'Spinach', 150, PantryUnit.g),
          det(id, 'Green peas', 300, PantryUnit.g, confirmed: false),
        ]);
    expect(d.canSave, isFalse);
    await expectLater(capture.commitDraft(d), throwsA(isA<ValidationException>()));
    expect(await pantry.getItems(), isEmpty);
  });

  test('multi-item save rolls back completely on failure', () async {
    final d = await draftWith((id) => [
          det(id, 'Spinach', 150, PantryUnit.g),
          det(id, 'Peas', 100, PantryUnit.g, mergeTarget: 'missing-item'),
        ]);
    await expectLater(capture.commitDraft(d), throwsA(isA<NotFoundException>()));
    expect(await pantry.getItems(), isEmpty, reason: 'no partial inventory update');
    expect(await pantry.getTransactions(), isEmpty);
    expect(await capture.getScanRecords(), isEmpty);
  });

  test('reviewed merge into an existing item adds compatible quantity', () async {
    final d1 = await draftWith((id) => [det(id, 'Oats', 500, PantryUnit.g)],
        method: CaptureMethod.manual);
    await capture.commitDraft(d1);
    final oats = (await pantry.getItems()).single;
    final d2 = await draftWith(
        (id) => [det(id, 'Oats', 0.5, PantryUnit.kg, mergeTarget: oats.id)],
        method: CaptureMethod.barcode);
    final r = await capture.commitDraft(d2);
    expect(r.mergedCount, 1);
    final items = await pantry.getItems();
    expect(items.length, 1);
    expect(items.single.quantity, 1000);
  });

  test('consume, set quantity, move, finish, discard, unavailable, remove',
      () async {
    final d = await draftWith((id) => [det(id, 'Spinach', 150, PantryUnit.g)],
        method: CaptureMethod.manual);
    await capture.commitDraft(d);
    final id = (await pantry.getItems()).single.id;

    expect((await pantry.consume(id, 50, PantryUnit.g)).quantity, 100);
    await expectLater(
        pantry.consume(id, 500, PantryUnit.g), throwsA(isA<ValidationException>()));
    await expectLater(
        pantry.consume(id, -1, PantryUnit.g), throwsA(isA<ValidationException>()));
    await expectLater(pantry.consume(id, 1, PantryUnit.pieces),
        throwsA(isA<ValidationException>()));
    expect((await pantry.consume(id, 0.05, PantryUnit.kg)).quantity, 50);

    expect((await pantry.setQuantity(id, 120, PantryUnit.g)).quantity, 120);

    final moved = await pantry.move(id, StorageLocation.freezer);
    expect(moved.storage, StorageLocation.freezer);
    expect(moved.foodState, FoodState.raw, reason: 'move never changes state');

    final unav = await pantry.setUnavailable(id, true);
    expect(unav.isUnavailable, isTrue);
    expect(unav.quantity, 120);

    expect((await pantry.discard(id, reason: 'Wilted')).quantity, 0);
    expect((await pantry.getItems()).single.isOut, isTrue,
        reason: 'discard keeps the record');

    final types = (await pantry.getTransactions()).map((t) => t.type).toSet();
    expect(types, containsAll([
      TransactionType.itemAdded,
      TransactionType.quantityConsumed,
      TransactionType.quantitySet,
      TransactionType.moved,
      TransactionType.markedUnavailable,
      TransactionType.discarded,
    ]));

    await pantry.remove(id);
    expect(await pantry.getItems(), isEmpty);
    expect((await pantry.getTransactions()).first.type,
        TransactionType.itemRemoved);
  });

  test('cooking deductions are atomic and validated', () async {
    final d = await draftWith((id) => [
          det(id, 'Spinach', 150, PantryUnit.g),
          det(id, 'Olive oil', 50, PantryUnit.ml),
        ], method: CaptureMethod.manual);
    await capture.commitDraft(d);
    final items = await pantry.getItems();
    final spinach = items.firstWhere((i) => i.name == 'Spinach');
    final oil = items.firstWhere((i) => i.name == 'Olive oil');
    final session = CookingSession(
      id: 's1',
      recipeId: 'spinach-chickpea-skillet',
      recipeName: 'Spinach chickpea skillet',
      mealType: MealType.lunch,
      status: CookingStatus.awaitingReview,
      servings: 2,
      currentStep: 4,
      completedSteps: const {1, 2, 3, 4},
      startedAt: DateTime.now(),
    );
    await cooking.saveSession(session);

    DeductionProposal prop(String itemId, String name, double before,
            PantryUnit u, double used) =>
        DeductionProposal(
          ingredientName: name,
          pantryItemId: itemId,
          itemName: name,
          before: before,
          itemUnit: u,
          used: used,
          usedUnit: u,
          plannedQuantity: used,
          plannedUnit: u,
        );

    // Over-deduction is rejected and nothing changes.
    await expectLater(
      cooking.confirmDeductions(session, [
        prop(spinach.id, 'Spinach', 150, PantryUnit.g, 100),
        prop(oil.id, 'Olive oil', 50, PantryUnit.ml, 80),
      ]),
      throwsA(isA<ValidationException>()),
    );
    expect((await pantry.getItem(spinach.id))!.quantity, 150);

    final done = await cooking.confirmDeductions(session, [
      prop(spinach.id, 'Spinach', 150, PantryUnit.g, 100),
      prop(oil.id, 'Olive oil', 50, PantryUnit.ml, 15).copyWith(skipped: true),
    ]);
    expect(done.status, CookingStatus.completed);
    expect((await pantry.getItem(spinach.id))!.quantity, 50);
    expect((await pantry.getItem(oil.id))!.quantity, 50, reason: 'skipped');
    final usage = await cooking.getUsage('s1');
    expect(usage.length, 2);
    expect(usage.firstWhere((u) => u.isSkipped).pantryItemId, oil.id);
    expect((await cooking.getHistory()).single.id, 's1');
  });

  test('deleting a scan record keeps confirmed inventory', () async {
    final d = await draftWith((id) => [det(id, 'Spinach', 150, PantryUnit.g)]);
    final r = await capture.commitDraft(d);
    await capture.deleteScanRecord(r.scanId!);
    expect(await capture.getScanRecords(), isEmpty);
    expect((await pantry.getItems()).length, 1);
    expect(photos.deleted, contains('/tmp/x.jpg'));
  });

  test('preferences persist', () async {
    final repo = SqliteRecipeRepository(db.db);
    await repo.savePreferences(const MealPreferences(
      mealType: MealType.lunch,
      maxMinutes: 30,
      excludedIngredients: ['peanut'],
    ));
    final p2 = await repo.getPreferences();
    expect(p2.mealType, MealType.lunch);
    expect(p2.maxMinutes, 30);
    expect(p2.excludedIngredients, ['peanut']);
  });

  test('data persists after close and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('pantry_db');
    final path = p.join(dir.path, 'smart_pantry.db');
    var fileDb = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final cap = SqliteCaptureRepository(fileDb.db, photos);
    final dr = await cap.createDraft(method: CaptureMethod.manual);
    await cap.commitDraft(dr.copyWith(
        detections: [det(dr.id, 'Rice', 1, PantryUnit.kg)]));
    await fileDb.close();

    fileDb = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    final items = await SqlitePantryRepository(fileDb.db, photos).getItems();
    expect(items.single.name, 'Rice');
    expect((await SqliteRecipeRepository(fileDb.db).getRecipes()).length, 4,
        reason: 'seed runs only once (onCreate)');
    await fileDb.close();
    await dir.delete(recursive: true);
  });
}
