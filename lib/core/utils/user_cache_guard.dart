import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sembast/sembast.dart';
import '../../data/repositories/meter_repository.dart';
import '../../presentation/auth_bloc/auth_bloc.dart';
import '../../presentation/bloc/energy_bloc.dart';
import '../../presentation/bloc/energy_event.dart';
import '../database/database_factory.dart';
import 'app_logger.dart';

/// Tracks the last signed-in user on this device and reloads the dashboard
/// whenever the user changes. All business data lives in Supabase, so no
/// cache wiping is needed — the new user simply fetches their own rows.
class UserCacheGuard extends StatefulWidget {
  final Widget child;
  const UserCacheGuard({super.key, required this.child});

  @override
  State<UserCacheGuard> createState() => _UserCacheGuardState();
}

class _UserCacheGuardState extends State<UserCacheGuard> {
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _initMeta();
  }

  Future<void> _initMeta() async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('meta');
      final rec = await store.record('last_user_id').get(db);
      final value = rec?['value'];
      if (value is String) {
        _lastUserId = value;
        AppLogger.i('Last signed-in user: ${value.substring(0, 8)}...');
      }
    } catch (e) {
      AppLogger.e('Failed to load meta', e);
    }
  }

  Future<void> _saveLastUserId(String userId) async {
    try {
      final db = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('meta');
      await store.record('last_user_id').put(db, {'value': userId});
    } catch (e) {
      AppLogger.e('Failed to persist user id', e);
    }
  }

  Future<void> _reloadForUser() async {
    if (!mounted) return;
    try {
      final meterRepo = context.read<MeterRepository>();
      meterRepo.refresh();
      context.read<EnergyBloc>().add(const LoadInitialDashboardData());
    } catch (e) {
      AppLogger.e('Failed to reload data for user', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AppAuthState>(
      listener: (context, state) async {
        if (state is AppAuthAuthenticated) {
          final differentUser =
              _lastUserId != null && _lastUserId != state.userId;
          if (differentUser) {
            await _reloadForUser();
          }
          _lastUserId = state.userId;
          await _saveLastUserId(state.userId);
        }
      },
      child: widget.child,
    );
  }
}
