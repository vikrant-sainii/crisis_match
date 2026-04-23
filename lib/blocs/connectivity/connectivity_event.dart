import 'package:equatable/equatable.dart';
import '../../repositories/low_network_repository.dart';

abstract class ConnectivityEvent extends Equatable {
  const ConnectivityEvent();
  @override
  List<Object?> get props => [];
}

class ObserveConnectivity extends ConnectivityEvent {}

class UpdateConnectivity extends ConnectivityEvent {
  final ConnectivityStatus status;
  final int latency;
  const UpdateConnectivity(this.status, this.latency);
  @override
  List<Object?> get props => [status, latency];
}
