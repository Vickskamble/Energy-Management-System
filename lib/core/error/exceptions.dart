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
