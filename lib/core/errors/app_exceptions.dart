/// Domain errors surfaced to controllers and shown to the user.
class ValidationException implements Exception {
  ValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  NotFoundException(this.message);
  final String message;
  @override
  String toString() => message;
}
