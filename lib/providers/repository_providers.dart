import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/sqlite_capture_repository.dart';
import '../data/repositories/sqlite_cooking_repository.dart';
import '../data/repositories/sqlite_pantry_repository.dart';
import '../data/repositories/sqlite_recipe_repository.dart';
import '../data/services/photo_storage.dart';
import '../features/capture/repositories/capture_repository.dart';
import '../features/cooking/repositories/cooking_repository.dart';
import '../features/inventory/repositories/pantry_repository.dart';
import '../features/meals/repositories/recipe_repository.dart';

/// Opened in `main()` before `runApp` and injected via an override.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

final photoStorageProvider = Provider<PhotoStorage>((ref) => LocalPhotoStorage());

final pantryRepositoryProvider = Provider<PantryRepository>(
  (ref) => SqlitePantryRepository(
    ref.watch(appDatabaseProvider).db,
    ref.watch(photoStorageProvider),
  ),
);

final captureRepositoryProvider = Provider<CaptureRepository>(
  (ref) => SqliteCaptureRepository(
    ref.watch(appDatabaseProvider).db,
    ref.watch(photoStorageProvider),
  ),
);

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => SqliteRecipeRepository(ref.watch(appDatabaseProvider).db),
);

final cookingRepositoryProvider = Provider<CookingRepository>(
  (ref) => SqliteCookingRepository(ref.watch(appDatabaseProvider).db),
);
