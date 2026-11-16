import '../models/cooking_models.dart';

abstract interface class CookingRepository {
  Future<void> saveSession(CookingSession session);
  Future<CookingSession?> getSession(String id);

  /// Most recent active/paused/awaiting-review session, if any.
  Future<CookingSession?> getOpenSession();

  /// Completed / closed sessions, newest first.
  Future<List<CookingSession>> getHistory();
  Future<List<CookingUsage>> getUsage(String sessionId);

  /// Applies the user-confirmed deductions in one SQLite transaction and
  /// marks the session completed. Skipped proposals are recorded but not
  /// deducted. Throws (and writes nothing) if any deduction is invalid.
  Future<CookingSession> confirmDeductions(
    CookingSession session,
    List<DeductionProposal> proposals,
  );
}
