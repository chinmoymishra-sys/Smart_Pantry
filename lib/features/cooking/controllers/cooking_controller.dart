import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/units.dart';
import '../../../providers/repository_providers.dart';
import '../../history/controllers/history_controller.dart';
import '../../inventory/controllers/inventory_controller.dart';
import '../../meals/controllers/meals_controller.dart';
import '../../meals/models/recipe.dart';
import '../../meals/models/recipe_match.dart';
import '../models/cooking_models.dart';

/// Focused cooking session. Starting, pausing, exiting and resuming never
/// change inventory; deductions are applied only by [confirmDeductions].
class CookingController extends AsyncNotifier<CookingSession?> {
  static const _uuid = Uuid();
  Timer? _ticker;
  bool _confirming = false;

  @override
  Future<CookingSession?> build() async {
    ref.onDispose(() => _ticker?.cancel());
    final s = await ref.read(cookingRepositoryProvider).getOpenSession();
    // A session restored after restart always comes back with its timer
    // paused — the user decides when to resume.
    return s?.copyWith(timerRunning: false);
  }

  CookingSession? get session => state.value;

  Recipe? recipeFor(CookingSession s) => ref.read(recipeProvider(s.recipeId));

  RecipeStep? currentStepOf(CookingSession s) {
    final r = recipeFor(s);
    if (r == null || r.steps.isEmpty) return null;
    return r.steps[(s.currentStep - 1).clamp(0, r.steps.length - 1)];
  }

  Future<void> _save(CookingSession s) async {
    state = AsyncData(s);
    await ref.read(cookingRepositoryProvider).saveSession(s);
  }

  void _set(CookingSession s) => state = AsyncData(s);

  Future<CookingSession> start(Recipe recipe, {required int servings}) async {
    _ticker?.cancel();
    final existing = session;
    if (existing != null &&
        existing.recipeId == recipe.id &&
        existing.status.isOpen) {
      // Re-entering the same recipe resumes instead of duplicating.
      return existing;
    }
    if (existing != null && existing.status.isOpen) {
      await _save(existing.copyWith(status: CookingStatus.abandoned));
    }
    final first = recipe.steps.isEmpty ? null : recipe.steps.first;
    final s = CookingSession(
      id: _uuid.v4(),
      recipeId: recipe.id,
      recipeName: recipe.name,
      mealType: recipe.mealType,
      status: CookingStatus.active,
      servings: servings,
      currentStep: 1,
      completedSteps: const {},
      startedAt: DateTime.now(),
      timerRemainingSeconds: first?.durationSeconds,
    );
    await _save(s);
    return s;
  }

  // ----------------------------------------------------------------- timer

  void toggleTimer() {
    final s = session;
    if (s == null || s.timerRemainingSeconds == null) return;
    if (s.timerRunning) {
      _ticker?.cancel();
      _save(s.copyWith(timerRunning: false));
    } else {
      if (s.timerRemainingSeconds! <= 0) return;
      _set(s.copyWith(timerRunning: true, status: CookingStatus.active));
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = session;
      if (s == null || !s.timerRunning) {
        _ticker?.cancel();
        return;
      }
      final next = (s.timerRemainingSeconds ?? 0) - 1;
      if (next <= 0) {
        _ticker?.cancel();
        _save(s.copyWith(timerRemainingSeconds: 0, timerRunning: false));
      } else {
        _set(s.copyWith(timerRemainingSeconds: next));
      }
    });
  }

  void restartTimer() {
    final s = session;
    if (s == null) return;
    final step = currentStepOf(s);
    if (step?.durationSeconds == null) return;
    _ticker?.cancel();
    _set(s.copyWith(
      timerRemainingSeconds: step!.durationSeconds,
      timerRunning: true,
      status: CookingStatus.active,
    ));
    _startTicker();
  }

  // ----------------------------------------------------------------- steps

  Future<void> goToStep(int step) async {
    final s = session;
    if (s == null) return;
    final r = recipeFor(s);
    if (r == null) return;
    final n = step.clamp(1, r.steps.length);
    _ticker?.cancel();
    await _save(s.copyWith(
      currentStep: n,
      timerRemainingSeconds: r.steps[n - 1].durationSeconds,
      clearTimer: r.steps[n - 1].durationSeconds == null,
      timerRunning: false,
    ));
  }

  /// Marks the current step complete. Returns true when every step is done.
  Future<bool> completeStepAndNext() async {
    final s = session;
    if (s == null) return false;
    final r = recipeFor(s);
    if (r == null) return false;
    final done = {...s.completedSteps, s.currentStep};
    if (done.length >= r.steps.length || s.currentStep >= r.steps.length) {
      _ticker?.cancel();
      await _save(s.copyWith(
        completedSteps: done,
        status: CookingStatus.awaitingReview,
        timerRunning: false,
      ));
      return true;
    }
    _ticker?.cancel();
    final next = s.currentStep + 1;
    await _save(s.copyWith(
      completedSteps: done,
      currentStep: next,
      timerRemainingSeconds: r.steps[next - 1].durationSeconds,
      clearTimer: r.steps[next - 1].durationSeconds == null,
      timerRunning: false,
    ));
    return false;
  }

  Future<void> previous() async {
    final s = session;
    if (s == null || s.currentStep <= 1) return;
    await goToStep(s.currentStep - 1);
  }

  /// Saves progress, pauses the in-app timer. No ingredients are deducted.
  Future<void> pauseAndExit() async {
    final s = session;
    if (s == null) return;
    _ticker?.cancel();
    await _save(s.copyWith(
      status: s.status == CookingStatus.awaitingReview
          ? CookingStatus.awaitingReview
          : CookingStatus.paused,
      timerRunning: false,
      pausedAt: DateTime.now(),
    ));
  }

  Future<void> resume() async {
    final s = session;
    if (s == null) return;
    await _save(s.copyWith(status: CookingStatus.active));
  }

  Future<void> restartFromBeginning() async {
    final s = session;
    if (s == null) return;
    final r = recipeFor(s);
    _ticker?.cancel();
    await _save(s.copyWith(
      status: CookingStatus.active,
      currentStep: 1,
      completedSteps: const {},
      timerRemainingSeconds: r?.steps.first.durationSeconds,
      timerRunning: false,
    ));
  }

  /// Ends the session without saving progress or touching inventory.
  Future<void> discard() async {
    final s = session;
    if (s == null) return;
    _ticker?.cancel();
    await ref
        .read(cookingRepositoryProvider)
        .saveSession(s.copyWith(status: CookingStatus.abandoned, timerRunning: false));
    state = const AsyncData(null);
  }

  /// Finished cooking but the user chose not to update inventory.
  Future<void> skipInventoryUpdate() async {
    final s = session;
    if (s == null) return;
    _ticker?.cancel();
    await ref.read(cookingRepositoryProvider).saveSession(s.copyWith(
          status: CookingStatus.completedWithoutUpdate,
          completedAt: DateTime.now(),
          timerRunning: false,
          clearTimer: true,
        ));
    state = const AsyncData(null);
    ref.invalidate(cookingHistoryProvider);
  }

  // ------------------------------------------------------------ deductions

  /// Proposes deductions for required + optional ingredients that are
  /// stocked. Unstocked ingredients are never deducted.
  List<DeductionProposal> proposeDeductions() {
    final s = session;
    if (s == null) return const [];
    final m = ref.read(
        recipeMatchProvider((recipeId: s.recipeId, servings: s.servings)));
    if (m == null) return const [];
    final out = <DeductionProposal>[];
    for (final im in m.ingredients) {
      final item = im.pantryItem;
      if (item == null) continue;
      if (im.availability == IngredientAvailability.missing) continue;
      final ing = im.ingredient;
      // Propose in the item's own unit when comparable; otherwise in the
      // recipe unit (the user must correct it before confirming).
      final inItem = tryConvertQuantity(ing.quantity, ing.unit, item.unit);
      final used = inItem ?? ing.quantity;
      final unit = inItem != null ? item.unit : ing.unit;
      out.add(DeductionProposal(
        ingredientName: ing.name,
        pantryItemId: item.id,
        itemName: item.name,
        before: item.quantity,
        itemUnit: item.unit,
        // Never clamped silently: an amount above stock is flagged in the
        // review UI and must be corrected or skipped before confirming.
        used: used,
        usedUnit: unit,
        plannedQuantity: ing.quantity,
        plannedUnit: ing.unit,
        packageNote: item.packageContentQuantity != null &&
                item.packageContentUnit != null &&
                inItem != null
            ? '${formatQuantity(item.packageContentQuantity! * used, item.packageContentUnit!)} drained'
            : null,
        skipped: !ing.isRequired,
      ));
    }
    return out;
  }

  Future<CookingSession?> confirmDeductions(
      List<DeductionProposal> proposals) async {
    final s = session;
    if (s == null) return null;
    if (_confirming) throw StateError('Already saving.');
    _confirming = true;
    try {
      final done = await ref
          .read(cookingRepositoryProvider)
          .confirmDeductions(s, proposals);
      state = const AsyncData(null);
      ref.read(lastCookedSessionProvider.notifier).set(done.id);
      await ref.read(inventoryProvider.notifier).refresh();
      ref.invalidate(cookingHistoryProvider);
      return done;
    } finally {
      _confirming = false;
    }
  }

  Future<void> recordFeedback(String sessionId, CookingFeedback feedback) async {
    final repo = ref.read(cookingRepositoryProvider);
    final s = await repo.getSession(sessionId);
    if (s == null) return;
    await repo.saveSession(s.copyWith(feedback: feedback));
    ref.invalidate(cookingHistoryProvider);
  }

  Future<void> saveToFavourites(String sessionId) async {
    final repo = ref.read(cookingRepositoryProvider);
    final s = await repo.getSession(sessionId);
    if (s == null) return;
    await repo.saveSession(s.copyWith(isFavoriteSaved: true));
    await ref.read(recipesProvider.notifier).setFavorite(s.recipeId, true);
    ref.invalidate(cookingHistoryProvider);
  }
}

final cookingControllerProvider =
    AsyncNotifierProvider<CookingController, CookingSession?>(
        CookingController.new);

class LastCookedSessionController extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final lastCookedSessionProvider =
    NotifierProvider<LastCookedSessionController, String?>(
        LastCookedSessionController.new);

final cookingSessionByIdProvider =
    FutureProvider.family<CookingSession?, String>(
        (ref, id) => ref.watch(cookingRepositoryProvider).getSession(id));

final cookingUsageProvider = FutureProvider.family<List<CookingUsage>, String>(
    (ref, id) => ref.watch(cookingRepositoryProvider).getUsage(id));
