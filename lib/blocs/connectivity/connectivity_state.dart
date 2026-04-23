import 'package:equatable/equatable.dart';
import '../../repositories/low_network_repository.dart';

class ConnectivityState extends Equatable {
  final ConnectivityStatus status;
  final int latency;

  const ConnectivityState({
    this.status = ConnectivityStatus.online,
    this.latency = 0,
  });

  @override
  List<Object?> get props => [status, latency];
}

class ConnectivityInitial extends ConnectivityState {
  const ConnectivityInitial() : super(status: ConnectivityStatus.online, latency: 0);
}
