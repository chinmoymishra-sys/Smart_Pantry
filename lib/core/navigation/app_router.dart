import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/capture/views/screens/barcode_result_screen.dart';
import '../../features/capture/views/screens/barcode_scanner_screen.dart';
import '../../features/capture/views/screens/camera_capture_screen.dart';
import '../../features/capture/views/screens/capture_permission_screen.dart';
import '../../features/capture/views/screens/confirm_additions_screen.dart';
import '../../features/capture/views/screens/edit_detection_screen.dart';
import '../../features/capture/views/screens/inventory_saved_screen.dart';
import '../../features/capture/views/screens/manual_add_screen.dart';
import '../../features/capture/views/screens/manual_details_screen.dart';
import '../../features/capture/views/screens/recognition_screen.dart';
import '../../features/capture/views/screens/review_screen.dart';
import '../../features/capture/views/screens/scan_add_screen.dart';
import '../../features/capture/views/screens/selected_photo_screen.dart';
import '../../features/capture/views/screens/split_merge_screen.dart';
import '../../features/cooking/views/screens/cooking_complete_screen.dart';
import '../../features/cooking/views/screens/cooking_done_screen.dart';
import '../../features/cooking/views/screens/cooking_ingredients_screen.dart';
import '../../features/cooking/views/screens/cooking_step_screen.dart';
import '../../features/cooking/views/screens/deductions_screen.dart';
import '../../features/cooking/views/screens/resume_cooking_screen.dart';
import '../../features/history/views/screens/history_screen.dart';
import '../../features/inventory/views/screens/edit_item_screen.dart';
import '../../features/inventory/views/screens/inventory_filters_screen.dart';
import '../../features/inventory/views/screens/inventory_list_screen.dart';
import '../../features/inventory/views/screens/item_detail_screen.dart';
import '../../features/inventory/views/screens/lifecycle_screen.dart';
import '../../features/inventory/views/screens/move_item_screen.dart';
import '../../features/inventory/views/screens/quantity_screen.dart';
import '../../features/meals/views/screens/meal_filters_screen.dart';
import '../../features/meals/views/screens/meals_screen.dart';
import '../../features/meals/views/screens/recipe_detail_screen.dart';
import '../../features/meals/views/screens/recipe_instructions_screen.dart';
import '../../features/overview/views/screens/overview_screen.dart';
import '../widgets/app_bottom_navigation.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter() {
  GoRoute full(String path, Widget Function(GoRouterState s) build) => GoRoute(
        path: path,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => build(s),
      );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.overview,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.overview,
              builder: (_, _) => const OverviewScreen(),
            ),
            GoRoute(
              path: Routes.history,
              builder: (_, _) => const HistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.scan,
              builder: (_, _) => const ScanAddScreen(),
              routes: [
                GoRoute(
                  path: 'saved',
                  builder: (_, _) => const InventorySavedScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.inventory,
              builder: (_, _) => const InventoryListScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.meals,
              builder: (_, _) => const MealsScreen(),
              routes: [
                GoRoute(
                  path: 'resume',
                  builder: (_, _) => const ResumeCookingScreen(),
                ),
                GoRoute(
                  path: 'cooked/:sessionId',
                  builder: (_, s) =>
                      CookingDoneScreen(sessionId: s.pathParameters['sessionId']!),
                ),
              ],
            ),
          ]),
        ],
      ),
      // Capture & review
      full(Routes.camera, (_) => const CameraCaptureScreen()),
      full(Routes.selectedPhoto, (_) => const SelectedPhotoScreen()),
      full(Routes.recognition, (_) => const RecognitionScreen()),
      full(Routes.review, (_) => const ReviewScreen()),
      full('/capture/review/edit/:id',
          (s) => EditDetectionScreen(detectionId: s.pathParameters['id'])),
      full(Routes.newDetection, (_) => const EditDetectionScreen()),
      full(Routes.confirmAdditions, (_) => const ConfirmAdditionsScreen()),
      full('/capture/split-merge',
          (s) => SplitMergeScreen(focusId: s.uri.queryParameters['focus'])),
      full(Routes.barcode, (_) => const BarcodeScannerScreen()),
      full('/capture/barcode/result',
          (s) => BarcodeResultScreen(code: s.uri.queryParameters['code'] ?? '')),
      full(Routes.manualAdd, (_) => const ManualAddScreen()),
      full(Routes.manualDetails, (_) => const ManualDetailsScreen()),
      full('/capture/permission/:kind',
          (s) => CapturePermissionScreen(kind: s.pathParameters['kind']!)),
      // Inventory
      full(Routes.inventoryFilters, (_) => const InventoryFiltersScreen()),
      full('/inventory/item/:id',
          (s) => ItemDetailScreen(itemId: s.pathParameters['id']!)),
      full('/inventory/item/:id/quantity', (s) => QuantityScreen(
            itemId: s.pathParameters['id']!,
            startInSetMode: s.uri.queryParameters['mode'] == 'set',
          )),
      full('/inventory/item/:id/move',
          (s) => MoveItemScreen(itemId: s.pathParameters['id']!)),
      full('/inventory/item/:id/lifecycle',
          (s) => LifecycleScreen(itemId: s.pathParameters['id']!)),
      full('/inventory/item/:id/edit',
          (s) => EditItemScreen(itemId: s.pathParameters['id']!)),
      // Meals & cooking
      full(Routes.mealFilters, (_) => const MealFiltersScreen()),
      full('/meals/recipe/:id',
          (s) => RecipeDetailScreen(recipeId: s.pathParameters['id']!)),
      full('/meals/recipe/:id/instructions',
          (s) => RecipeInstructionsScreen(recipeId: s.pathParameters['id']!)),
      full(Routes.cookStep, (_) => const CookingStepScreen()),
      full(Routes.cookIngredients, (_) => const CookingIngredientsScreen()),
      full(Routes.cookComplete, (_) => const CookingCompleteScreen()),
      full(Routes.cookDeductions, (_) => const DeductionsScreen()),
    ],
  );
}
