sealed class AppAuthEvent {
  const AppAuthEvent();
}

final class AppAuthLoginRequested extends AppAuthEvent {
  final String email;
  final String password;
  const AppAuthLoginRequested({required this.email, required this.password});
}

final class AppAuthRegisterRequested extends AppAuthEvent {
  final String email;
  final String password;
  const AppAuthRegisterRequested({required this.email, required this.password});
}

final class AppAuthLogoutRequested extends AppAuthEvent {
  const AppAuthLogoutRequested();
}

final class AppAuthCheckRequested extends AppAuthEvent {
  const AppAuthCheckRequested();
}

/// Internal event fired when Supabase auth state changes.
/// Needs to be in this library because [AppAuthEvent] is sealed.
class AppAuthStateChanged extends AppAuthEvent {
  final Object? authData;
  const AppAuthStateChanged(this.authData);
}
