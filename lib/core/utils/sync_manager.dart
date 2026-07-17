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
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}
