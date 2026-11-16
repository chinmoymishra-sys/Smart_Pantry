import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/pantry_enums.dart';
import '../../../core/utils/units.dart';

/// What a recognition service reported for a photo.
enum RecognitionOutcome {
  /// One or more foods were suggested. Each is only a suggestion until the
  /// user confirms it in review.
  detected,

  /// The service ran but couldn't make out any food.
  noFood,

  /// No recognition service is available in this build / right now.
  unavailable,
}

/// A single suggestion from a recognition service. Quantities are visual
/// estimates at best and may be absent.
class RecognizedFood {
  const RecognizedFood({
    required this.name,
    this.category = FoodCategory.other,
    this.quantity,
    this.unit = PantryUnit.pieces,
  });

  final String name;
  final FoodCategory category;
  final double? quantity;
  final PantryUnit unit;
}

class RecognitionResult {
  const RecognitionResult._(this.outcome, [this.foods = const []]);

  const RecognitionResult.detected(List<RecognizedFood> foods)
    : this._(RecognitionOutcome.detected, foods);

  static const noFood = RecognitionResult._(RecognitionOutcome.noFood);
  static const unavailable = RecognitionResult._(
    RecognitionOutcome.unavailable,
  );

  final RecognitionOutcome outcome;
  final List<RecognizedFood> foods;
}

/// Boundary for photo recognition. A real, connected implementation can be
/// swapped in by overriding [recognitionServiceProvider].
abstract interface class RecognitionService {
  bool get isAvailable;
  Future<RecognitionResult> identify(String photoPath);
}

/// The only implementation in this build: there is no recognition service,
/// so it never produces detections. No fake results, ever.
class UnavailableRecognitionService implements RecognitionService {
  const UnavailableRecognitionService();

  @override
  bool get isAvailable => false;

  @override
  Future<RecognitionResult> identify(String photoPath) async =>
      RecognitionResult.unavailable;
}

final recognitionServiceProvider = Provider<RecognitionService>(
  (ref) => const UnavailableRecognitionService(),
);
