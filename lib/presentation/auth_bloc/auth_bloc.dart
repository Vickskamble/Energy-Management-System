import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/network/session_guard.dart';
import '../../core/network/supabase_client.dart';
import '../../core/utils/app_logger.dart';
import 'auth_event.dart';
import 'auth_state.dart';
export 'auth_event.dart';
export 'auth_state.dart';

class AuthBloc extends Bloc<AppAuthEvent, AppAuthState> {
  StreamSubscription<AuthState>? _authSub;

  AuthBloc() : super(const AppAuthInitial()) {
    on<AppAuthCheckRequested>(_onCheckAuth);
    on<AppAuthLoginRequested>(_onLogin);
    on<AppAuthRegisterRequested>(_onRegister);
    on<AppAuthLogoutRequested>(_onLogout);
    on<AppAuthPasswordResetRequested>(_onPasswordReset);
    on<AppAuthStateChanged>(_onSupabaseAuthChanged);

    // Try to set up auth listener — safe even if Supabase isn't ready yet
    _trySetupAuthListener();
  }

  void _trySetupAuthListener() {
    try {
      if (SupabaseClientManager.isInitialized) {
        _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
          (data) => add(AppAuthStateChanged(data)),
        );
      }
    } catch (_) {
      // Supabase not ready — will check again on next event
    }
  }

  void _onSupabaseAuthChanged(
    AppAuthStateChanged event,
    Emitter<AppAuthState> emit,
  ) {
    final data = event.authData;
    if (data == null) {
      _handleUnauthenticated(emit);
      return;
    }
    try {
      final authState = data as AuthState;
      final session = authState.session;
      if (session != null) {
        // Enforce one-device-per-account BEFORE showing the app.
        _enforceAndEmitAuthenticated(
          userId: session.user.id,
          email: session.user.email ?? '',
          emit: emit,
        );
      } else {
        _handleUnauthenticated(emit);
      }
    } catch (_) {
      // Cast failed — session not available
      _handleUnauthenticated(emit);
    }
  }

  void _onCheckAuth(AppAuthCheckRequested event, Emitter<AppAuthState> emit) {
    if (!SupabaseClientManager.isInitialized) {
      emit(const AppAuthUnauthenticated());
      return;
    }
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        _enforceAndEmitAuthenticated(
          userId: session.user.id,
          email: session.user.email ?? '',
          emit: emit,
        );
      } else {
        emit(const AppAuthUnauthenticated());
      }
    } catch (_) {
      emit(const AppAuthUnauthenticated());
    }
  }

  /// Single-device enforcement:
  ///  - check() conflict  → sign out + show error
  ///  - otherwise         → take over the session row, start heartbeat,
  ///                        then emit authenticated.
  Future<void> _enforceAndEmitAuthenticated({
    required String userId,
    required String email,
    required Emitter<AppAuthState> emit,
  }) async {
    if (isClosed) return;
    final status = await SessionGuard.instance.check(userId);
    if (isClosed) return;
    if (status == SessionStatus.conflict) {
      await _signOutQuietly();
      if (!isClosed) {
        emit(
          const AppAuthError(
            'This account is already signed in on another device. '
            'Sign out there first, then try again.',
          ),
        );
      }
      return;
    }
    await SessionGuard.instance.takeOver(userId);
    SessionGuard.instance.startHeartbeat(
      userId: userId,
      onConflict: () => _onHeartbeatConflict(emit),
    );

    // Tariff settings are per-user cloud data — load them before the UI
    // builds so bill calculations use this account's rates.
    try {
      await TariffStore.load(userId: userId);
    } catch (e) {
      AppLogger.w('Tariff load failed, using defaults: $e');
    }

    if (!isClosed) {
      emit(AppAuthAuthenticated(userId: userId, email: email));
    }
  }

  /// Called when the heartbeat detects another device took over the session.
  Future<void> _onHeartbeatConflict(Emitter<AppAuthState> emit) async {
    if (isClosed) return;
    await SessionGuard.instance.stopHeartbeat();
    await _signOutQuietly();
    if (!isClosed) {
      emit(
        const AppAuthError(
          'Signed out — this account is now logged in on another device.',
        ),
      );
    }
  }

  void _handleUnauthenticated(Emitter<AppAuthState> emit) {
    SessionGuard.instance.stopHeartbeat();
    emit(const AppAuthUnauthenticated());
  }

  Future<void> _signOutQuietly() async {
    try {
      await Supabase.instance.client.auth.signOut().timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      // Best-effort — RLS still protects the data.
    }
  }

  Future<void> _onLogin(
    AppAuthLoginRequested event,
    Emitter<AppAuthState> emit,
  ) async {
    emit(const AppAuthLoading());
    try {
      if (!SupabaseClientManager.isInitialized) {
        await SupabaseClientManager.initialize();
        _trySetupAuthListener();
      }
      await Supabase.instance.client.auth
          .signInWithPassword(
            email: event.email.trim(),
            password: event.password,
          )
          .timeout(const Duration(seconds: 15));
      // Drive the authenticated flow directly from the sign-in result so we
      // never depend on the (possibly delayed) auth-state listener.
      if (isClosed) return;
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await _enforceAndEmitAuthenticated(
          userId: user.id,
          email: user.email ?? '',
          emit: emit,
        );
      }
    } on TimeoutException {
      emit(const AppAuthError('Connection timed out. Check your network.'));
    } on AuthException catch (e) {
      emit(AppAuthError(e.message));
    } catch (e) {
      AppLogger.e('Login failed', e);
      emit(const AppAuthError('Unable to sign in. Please check your credentials.'));
    }
  }

  Future<void> _onRegister(
    AppAuthRegisterRequested event,
    Emitter<AppAuthState> emit,
  ) async {
    emit(const AppAuthLoading());
    try {
      if (!SupabaseClientManager.isInitialized) {
        await SupabaseClientManager.initialize();
        _trySetupAuthListener();
      }
      final res = await Supabase.instance.client.auth
          .signUp(email: event.email.trim(), password: event.password)
          .timeout(const Duration(seconds: 15));
      if (res.session != null) {
        final uid = res.session!.user.id;
        // Remove the auto-created session row so the fresh account isn't
        // "active on a device" before the user signs in properly.
        await SessionGuard.instance.stopHeartbeat(releaseSession: true);
        await SessionGuard.instance.release(uid);
        await Supabase.instance.client.auth.signOut();
      }
      emit(const AppAuthRegisterSuccess());
    } on TimeoutException {
      emit(const AppAuthError('Connection timed out. Check your network.'));
    } on AuthException catch (e) {
      emit(AppAuthError(e.message));
    } catch (e) {
      AppLogger.e('Registration failed', e);
      emit(const AppAuthError('Registration failed. Please try again.'));
    }
  }

  Future<void> _onLogout(
    AppAuthLogoutRequested event,
    Emitter<AppAuthState> emit,
  ) async {
    emit(const AppAuthLoading());
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      await SessionGuard.instance.stopHeartbeat(releaseSession: true);
      if (uid != null) {
        await SessionGuard.instance.release(uid);
      }
      await Supabase.instance.client.auth.signOut().timeout(
        const Duration(seconds: 15),
      );
      emit(const AppAuthUnauthenticated());
    } on TimeoutException {
      emit(const AppAuthError('Connection timed out. Check your network.'));
    } on AuthException catch (e) {
      emit(AppAuthError(e.message));
    } catch (e) {
      AppLogger.e('Logout failed', e);
      emit(const AppAuthError('Unable to sign out right now.'));
    }
  }

  Future<void> _onPasswordReset(
    AppAuthPasswordResetRequested event,
    Emitter<AppAuthState> emit,
  ) async {
    emit(const AppAuthLoading());
    try {
      if (!SupabaseClientManager.isInitialized) {
        await SupabaseClientManager.initialize();
        _trySetupAuthListener();
      }
      await Supabase.instance.client.auth
          .resetPasswordForEmail(event.email.trim())
          .timeout(const Duration(seconds: 15));
      emit(const AppAuthPasswordResetSent());
    } on TimeoutException {
      emit(const AppAuthError('Connection timed out. Check your network.'));
    } on AuthException catch (e) {
      emit(AppAuthError(e.message));
    } catch (e) {
      AppLogger.e('Password reset failed', e);
      emit(const AppAuthError('Unable to send the reset link. Please try again.'));
    }
  }

  @override
  Future<void> close() {
    SessionGuard.instance.stopHeartbeat();
    _authSub?.cancel();
    return super.close();
  }
}
