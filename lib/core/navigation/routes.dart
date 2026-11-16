/// Central route paths. Use `context.go` for tab roots and `context.push`
/// for detail and multi-step flows.
abstract final class Routes {
  // Tab roots (bottom navigation visible)
  static const overview = '/';
  static const scan = '/scan';
  static const inventory = '/inventory';
  static const meals = '/meals';

  // Inside tab branches (bottom navigation stays visible, per design)
  static const history = '/history';
  static const saved = '/scan/saved';
  static const cookResume = '/meals/resume';
  static String cookDone(String sessionId) => '/meals/cooked/$sessionId';

  // Capture & review (full screen)
  static const camera = '/capture/camera';
  static const selectedPhoto = '/capture/photo';
  static const recognition = '/capture/recognition';
  static const review = '/capture/review';
  static String editDetection(String id) => '/capture/review/edit/$id';
  static const newDetection = '/capture/review/new';
  static const confirmAdditions = '/capture/confirm';
  static String splitMerge([String? focusId]) =>
      focusId == null ? '/capture/split-merge' : '/capture/split-merge?focus=$focusId';
  static const barcode = '/capture/barcode';
  static String barcodeResult(String code) =>
      '/capture/barcode/result?code=${Uri.encodeQueryComponent(code)}';
  static const manualAdd = '/capture/manual';
  static const manualDetails = '/capture/manual/details';
  static String permission(String kind) => '/capture/permission/$kind';

  // Inventory details (full screen)
  static const inventoryFilters = '/inventory/filters';
  static String item(String id) => '/inventory/item/$id';
  static String itemQuantity(String id, {bool setMode = false}) =>
      '/inventory/item/$id/quantity${setMode ? '?mode=set' : ''}';
  static String itemMove(String id) => '/inventory/item/$id/move';
  static String itemLifecycle(String id) => '/inventory/item/$id/lifecycle';
  static String itemEdit(String id) => '/inventory/item/$id/edit';

  // Meals & cooking (full screen)
  static const mealFilters = '/meals/filters';
  static String recipe(String id) => '/meals/recipe/$id';
  static String recipeInstructions(String id) => '/meals/recipe/$id/instructions';
  static const cookStep = '/cook';
  static const cookIngredients = '/cook/ingredients';
  static const cookComplete = '/cook/complete';
  static const cookDeductions = '/cook/deductions';
}
