import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/low_network_repository.dart';
import 'connectivity_event.dart';
import 'connectivity_state.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final LowNetworkRepository _repository;
  StreamSubscription? _subscription;
  Timer? _latencyTimer;

  ConnectivityBloc({required LowNetworkRepository repository})
      : _repository = repository,
        super(const ConnectivityInitial()) {
    on<ObserveConnectivity>(_onObserve);
    on<UpdateConnectivity>(_onUpdate);
  }

  void _onObserve(ObserveConnectivity event, Emitter<ConnectivityState> emit) {
    _subscription?.cancel();
    _subscription = _repository.statusStream.listen((status) async {
      final latency = await _repository.getLatency();
      add(UpdateConnectivity(status, latency));
    });

    // Periodically refresh latency every 10 seconds if not offline
    _latencyTimer?.cancel();
    _latencyTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (state.status != ConnectivityStatus.offline) {
        final latency = await _repository.getLatency();
        // If latency is huge, it might mean we are low network
        ConnectivityStatus newStatus = state.status;
        if (latency > 800) {
          newStatus = ConnectivityStatus.lowNetwork;
        } else if (latency < 400 && state.status == ConnectivityStatus.lowNetwork) {
          newStatus = ConnectivityStatus.online;
        }
        add(UpdateConnectivity(newStatus, latency));
      }
    });
  }

  void _onUpdate(UpdateConnectivity event, Emitter<ConnectivityState> emit) {
    emit(ConnectivityState(status: event.status, latency: event.latency));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _latencyTimer?.cancel();
    return super.close();
  }
}
