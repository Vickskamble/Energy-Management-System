sealed class AppAuthState {
  const AppAuthState();
}

final class AppAuthInitial extends AppAuthState {
  const AppAuthInitial();
}

final class AppAuthLoading extends AppAuthState {
  const AppAuthLoading();
}

final class AppAuthAuthenticated extends AppAuthState {
  final String userId;
  final String email;
  const AppAuthAuthenticated({required this.userId, required this.email});
}

final class AppAuthUnauthenticated extends AppAuthState {
  const AppAuthUnauthenticated();
}

final class AppAuthError extends AppAuthState {
  final String message;
  const AppAuthError(this.message);
}

final class AppAuthRegisterSuccess extends AppAuthState {
  const AppAuthRegisterSuccess();
}

final class AppAuthPasswordResetSent extends AppAuthState {
  const AppAuthPasswordResetSent();
}
