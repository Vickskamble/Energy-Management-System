import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../presentation/bloc/energy_bloc.dart';
import '../../presentation/bloc/energy_event.dart';

class SyncManager {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final Connectivity _connectivity;

  SyncManager({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  void start(EnergyBloc bloc) {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        bloc.add(const SyncOfflineCachedLogs());
      }
    });
    _syncPendingIfOnline(bloc);
  }

  /// Sync pending logs once on app start — connectivity-change events never
  /// fire when the device is already continuously connected.
  Future<void> _syncPendingIfOnline(EnergyBloc bloc) async {
    try {
      final results = await _connectivity.checkConnectivity();
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        bloc.add(const SyncOfflineCachedLogs());
      }
    } catch (_) {
      // Connectivity check failed — the change listener will cover us later.
    }
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
