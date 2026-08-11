sealed class AppException implements Exception {
  final String message;
  final String? code;
  const AppException(this.message, {this.code});

  @override
  String toString() =>
      code == null ? message : '$message ($code)';
}

final class LocalStorageException extends AppException {
  const LocalStorageException(super.message, {super.code});
}

final class RemoteStorageException extends AppException {
  const RemoteStorageException(super.message, {super.code});
}

final class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

final class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

final class SubscriptionException extends AppException {
  const SubscriptionException(super.message, {super.code});
}

/// Thrown when the account's trial/subscription expired — writes are blocked.
final class ReadOnlyAccountException extends AppException {
  const ReadOnlyAccountException(super.message, {super.code});
}

/// Thrown when adding a meter would exceed the plan's meter allowance.
final class MeterLimitException extends AppException {
  const MeterLimitException(super.message, {super.code});
}
