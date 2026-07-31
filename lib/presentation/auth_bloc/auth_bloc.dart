import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';
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
      emit(const AppAuthUnauthenticated());
      return;
    }
    try {
      final authState = data as AuthState;
      final session = authState.session;
      if (session != null) {
        emit(
          AppAuthAuthenticated(
            userId: session.user.id,
            email: session.user.email ?? '',
          ),
        );
      } else {
        emit(const AppAuthUnauthenticated());
      }
    } catch (_) {
      // Cast failed — session not available
      emit(const AppAuthUnauthenticated());
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
        emit(
          AppAuthAuthenticated(
            userId: session.user.id,
            email: session.user.email ?? '',
          ),
        );
      } else {
        emit(const AppAuthUnauthenticated());
      }
    } catch (_) {
      emit(const AppAuthUnauthenticated());
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
    } on TimeoutException {
      emit(const AppAuthError('Connection timed out. Check your network.'));
    } on AuthException catch (e) {
      emit(AppAuthError(e.message));
    } catch (e) {
      emit(AppAuthError('Login failed: $e'));
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
        await Supabase.instance.client.auth.signOut();
      }
      emit(const AppAuthRegisterSuccess());
    } on TimeoutException {
      emit(const AppAuthError('Connection timed out. Check your network.'));
    } on AuthException catch (e) {
      emit(AppAuthError(e.message));
    } catch (e) {
      emit(AppAuthError('Registration failed: $e'));
    }
  }

  Future<void> _onLogout(
    AppAuthLogoutRequested event,
    Emitter<AppAuthState> emit,
  ) async {
    emit(const AppAuthLoading());
    try {
      await Supabase.instance.client.auth.signOut().timeout(
        const Duration(seconds: 15),
      );
      emit(const AppAuthUnauthenticated());
    } on TimeoutException {
      emit(const AppAuthError('Connection timed out. Check your network.'));
    } on AuthException catch (e) {
      emit(AppAuthError(e.message));
    } catch (e) {
      emit(AppAuthError('Logout failed: $e'));
    }
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
