import 'package:equatable/equatable.dart';

abstract class SosState extends Equatable {
  const SosState();

  @override
  List<Object?> get props => [];
}

/// SOS toggle is OFF — not listening
class SosDisabled extends SosState {}

/// Background service is running, waiting for power button trigger
class SosListening extends SosState {
  final double? gZ;
  final int? shakeCount;

  const SosListening({this.gZ, this.shakeCount});

  @override
  List<Object?> get props => [gZ, shakeCount];
}

/// Wake word detected — app launched to foreground
class SosActivated extends SosState {}

/// Prompt user to choose: Woman Safety SOS or Voice Assist
class SosAwaitingAction extends SosState {
  final double lat;
  final double lon;
  const SosAwaitingAction({required this.lat, required this.lon});

  @override
  List<Object?> get props => [lat, lon];
}

/// Recording the victim's distress message (dynamic capturing)
class SosCapturing extends SosState {
  final String liveText;
  const SosCapturing(this.liveText);

  @override
  List<Object?> get props => [liveText];
}
/// New terminal state: Voice message captured, ready for handoff
class SosCaptured extends SosState {
  final String message;
  const SosCaptured(this.message);

  @override
  List<Object?> get props => [message];
}

/// No internet detected -> Show SMS input sheet
class SosOfflineInputPending extends SosState {
  final double lat;
  final double lon;
  const SosOfflineInputPending({required this.lat, required this.lon});

  @override
  List<Object?> get props => [lat, lon];
}

/// Offline SMS successfully sent
class SosOfflineSuccess extends SosState {
  final String phoneNumber;
  const SosOfflineSuccess(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

/// Something went wrong
class SosError extends SosState {
  final String message;
  const SosError(this.message);

  @override
  List<Object?> get props => [message];
}
