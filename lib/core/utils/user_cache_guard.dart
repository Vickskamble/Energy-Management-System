import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sembast/sembast.dart';
import '../../data/repositories/energy_repository.dart';
import '../../data/repositories/meter_repository.dart';
import '../../presentation/auth_bloc/auth_bloc.dart';
import '../../presentation/bloc/energy_bloc.dart';
import '../../presentation/bloc/energy_event.dart';
import '../database/database_factory.dart';
import 'app_logger.dart';

/// Wipes the local cache whenever the logged-in user changes,
/// so one user's readings/meters never leak to another user on the same device.
class UserCacheGuard extends StatefulWidget {
  final Widget child;
  const UserCacheGuard({super.key, required this.child});

  @override
  State<UserCacheGuard> createState() => _UserCacheGuardState();
}

class _UserCacheGuardState extends State<UserCacheGuard> {
  String? _lastUserId;
  Database? _metaDb;

  @override
  void initState() {
    super.initState();
    _initMeta();
  }

  Future<void> _initMeta() async {
    try {
      _metaDb = await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('meta');
      final rec = await store.record('last_user_id').get(_metaDb!);
      final value = rec?['value'];
      if (value is String) {
        _lastUserId = value;
        AppLogger.i('Last cached user: ${value.substring(0, 8)}...');
      }
    } catch (e) {
      AppLogger.e('Failed to load meta', e);
    }
  }

  Future<void> _saveLastUserId(String userId) async {
    try {
      _metaDb ??= await getDatabaseFactory().openDatabase('ems_meta.db');
      final store = stringMapStoreFactory.store('meta');
      await store.record('last_user_id').put(_metaDb!, {'value': userId});
    } catch (e) {
      AppLogger.e('Failed to persist user id', e);
    }
  }

  Future<void> _wipeCaches() async {
    if (!mounted) return;
    try {
      final energyRepo = context.read<EnergyRepository>();
      final meterRepo = context.read<MeterRepository>();
      await energyRepo.clearLocalCache();
      await meterRepo.clearLocalCache();
    } catch (e) {
      AppLogger.e('Cache wipe failed', e);
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
            await _wipeCaches();
            if (!context.mounted) return;
            context.read<EnergyBloc>().add(const LoadInitialDashboardData());
          }
          _lastUserId = state.userId;
          await _saveLastUserId(state.userId);
        } else if (state is AppAuthUnauthenticated) {
          await _wipeCaches();
        }
      },
      child: widget.child,
    );
  }
}
